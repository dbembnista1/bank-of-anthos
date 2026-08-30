terraform {
  required_version = ">= 1.5.0"

  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(var.common_tags, {
      Project     = var.project
      Owner       = var.owner
      Environment = var.environment
      ManagedBy   = "Terraform"
    })
  }

  # Subnet cluster tags are owned by the EKS module (aws_ec2_tag), not by aws_subnet
  ignore_tags {
    key_prefixes = ["kubernetes.io/cluster/"]
  }
}

data "aws_caller_identity" "current" {}

resource "terraform_data" "ingress_guards" {
  input = {
    ingress_environments = var.ingress_environments
    enabled_environments = var.enabled_environments
    ingress_domain       = var.ingress_domain
    manage_dns           = var.ingress_manage_dns_records
  }

  lifecycle {
    precondition {
      condition = alltrue([
        for env in var.ingress_environments : contains(var.enabled_environments, env)
      ])
      error_message = "ingress_environments must be a subset of enabled_environments."
    }
    precondition {
      condition     = !var.ingress_manage_dns_records || var.ingress_domain != ""
      error_message = "ingress_manage_dns_records requires a non-empty ingress_domain."
    }
  }
}

module "vpc" {
  source = "./modules/vpc"

  name                 = var.vpc_name
  cidr                 = var.vpc_cidr
  azs                  = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
}

module "eks" {
  source = "./modules/eks"

  cluster_name    = var.eks_cluster_name
  cluster_version = var.eks_cluster_version

  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.private_subnet_ids
  public_subnet_ids = module.vpc.public_subnet_ids

  cluster_endpoint_public_access  = var.eks_endpoint_public_access
  cluster_endpoint_private_access = var.eks_endpoint_private_access

  node_instance_types = var.eks_node_instance_types
  node_min_size       = var.eks_node_min_size
  node_max_size       = var.eks_node_max_size
  node_desired_size   = contains(var.enabled_environments, "prod") ? 3 : 2
}

module "ecr" {
  source = "./modules/ecr"

  repository_names    = var.ecr_repository_names
  lifecycle_keep_last = var.ecr_lifecycle_keep_last
  force_delete        = var.ecr_force_delete
}

module "rds" {
  source = "./modules/rds"

  name_prefix                = var.rds_name_prefix
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.private_subnet_ids
  allowed_security_group_ids = [module.eks.node_security_group_id]

  instances = {
    for k, v in local.rds_instances : k => {
      identifier = v.identifier
      db_name    = v.db_name
      username   = v.username
    }
  }
  engine_version          = var.rds_engine_version
  instance_class          = var.rds_instance_class
  allocated_storage       = var.rds_allocated_storage
  max_allocated_storage   = var.rds_max_allocated_storage
  multi_az                = var.rds_multi_az
  backup_retention_period = var.rds_backup_retention_period
  deletion_protection     = var.rds_deletion_protection
  skip_final_snapshot     = var.rds_skip_final_snapshot
}

module "aws_load_balancer_controller" {
  source = "./modules/aws-load-balancer-controller"

  cluster_name         = module.eks.cluster_name
  vpc_id               = module.vpc.vpc_id
  region               = var.aws_region
  namespace            = var.alb_controller_namespace
  chart_version        = var.alb_controller_chart_version
  service_account_name = var.alb_controller_service_account_name
  iam_role_name        = var.alb_controller_iam_role_name
  oidc_provider_arn    = module.eks.oidc_provider_arn
}

# Hosted zone + ACM wildcard. Skipped when ingress_domain is empty (lab HTTP ALB).
module "ingress_dns" {
  count  = var.ingress_domain != "" ? 1 : 0
  source = "./modules/ingress-dns"

  domain             = var.ingress_domain
  cluster_name       = module.eks.cluster_name
  group_name         = local.ingress_group_name
  record_names       = var.ingress_environments
  manage_dns_records = var.ingress_manage_dns_records

  depends_on = [terraform_data.ingress_guards]
}

module "external_secrets" {
  source = "./modules/external-secrets"

  namespace            = var.eso_namespace
  chart_version        = var.eso_chart_version
  service_account_name = var.eso_service_account_name
  iam_role_name        = var.eso_iam_role_name

  oidc_provider_arn    = module.eks.oidc_provider_arn
  oidc_provider        = module.eks.oidc_provider
  secrets_manager_arns = local.eso_secrets_manager_arns

  # LBC registers cluster-wide webhooks; Helm Service creates must not race empty endpoints.
  depends_on = [module.aws_load_balancer_controller]
}

module "argocd" {
  source = "./modules/argocd-bootstrap"

  repo_url    = var.argocd_repo_url
  gh_token    = var.argocd_gh_token
  gh_username = var.argocd_gh_username

  target_revision            = var.argocd_target_revision
  chart_version              = var.argocd_chart_version
  apps_chart_version         = var.argocd_apps_chart_version
  enabled_environments       = var.enabled_environments
  destination_namespaces     = local.argocd_destination_namespaces
  gitops_app_paths           = local.gitops_app_paths
  external_secrets_namespace = var.eso_namespace
  database_hosts             = local.database_hosts
  database_secret_arns       = local.database_secret_arns
  image_registry             = local.ecr_image_registry
  frontend_ingress           = local.frontend_ingress

  depends_on = [
    module.aws_load_balancer_controller,
    terraform_data.ingress_guards,
  ]
}
