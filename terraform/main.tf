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
  node_desired_size   = var.eks_node_desired_size
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

  instances               = local.rds_instances
  engine_version          = var.rds_engine_version
  instance_class          = var.rds_instance_class
  allocated_storage       = var.rds_allocated_storage
  max_allocated_storage   = var.rds_max_allocated_storage
  multi_az                = var.rds_multi_az
  backup_retention_period = var.rds_backup_retention_period
  deletion_protection     = var.rds_deletion_protection
  skip_final_snapshot     = var.rds_skip_final_snapshot
}

module "argocd" {
  source = "./modules/argocd-bootstrap"

  repo_url    = var.argocd_repo_url
  gh_token    = var.argocd_gh_token
  gh_username = var.argocd_gh_username

  target_revision        = var.argocd_target_revision
  chart_version          = var.argocd_chart_version
  apps_chart_version     = var.argocd_apps_chart_version
  enabled_environments   = var.enabled_environments
  destination_namespaces = local.app_namespaces
  gitops_app_paths       = local.gitops_app_paths
}
