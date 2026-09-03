output "vpc_id" {
  description = "ID of the shared VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the shared VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs (ALB / NAT)"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs (EKS nodes, RDS)"
  value       = module.vpc.private_subnet_ids
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs"
  value       = module.vpc.nat_gateway_ids
}

output "eks_cluster_name" {
  description = "Name of the shared EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "API server endpoint of the EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_certificate_authority_data" {
  description = "Base64-encoded CA data for kubeconfig"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "eks_oidc_provider_arn" {
  description = "IAM OIDC provider ARN for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "eks_oidc_provider" {
  description = "OIDC provider URL without https:// (for IAM trust policies)"
  value       = module.eks.oidc_provider
}

output "eks_node_security_group_id" {
  description = "Node security group ID (source for RDS ingress)"
  value       = module.eks.node_security_group_id
}

output "eks_cluster_security_group_id" {
  description = "Cluster security group ID"
  value       = module.eks.cluster_security_group_id
}

output "eks_cluster_admin_role_arn" {
  description = "Assume this role for kubectl: aws eks update-kubeconfig --name <cluster> --role-arn <this>"
  value       = module.eks.cluster_admin_role_arn
}

output "ecr_repository_urls" {
  description = "Map of ECR repository name => URL (CI push / Helm image values)"
  value       = module.ecr.repository_urls
}

output "ecr_repository_arns" {
  description = "Map of ECR repository name => ARN (IAM in CI phase)"
  value       = module.ecr.repository_arns
}

output "ecr_registry_id" {
  description = "AWS account ID hosting the ECR registry"
  value       = module.ecr.registry_id
}

output "ecr_image_registry" {
  description = "ECR registry URL injected into Argo as global.imageRegistry"
  value       = local.ecr_image_registry
}

output "enabled_environments" {
  description = "App environments provisioned (RDS + Argo root Apps)"
  value       = var.enabled_environments
}

output "app_namespaces" {
  description = "Kubernetes namespaces for enabled app environments"
  value       = local.app_namespaces
}

output "rds_security_group_id" {
  description = "Security group ID for RDS instances"
  value       = module.rds.security_group_id
}

output "rds_instance_endpoints" {
  description = "Nested map env => { accounts, ledger } => endpoint hostname (for Helm values-*.yaml)"
  value = {
    for env in var.enabled_environments : env => {
      for svc in keys(local.app_db_services) :
      svc => module.rds.instance_endpoints["${env}-${svc}"]
    }
  }
}

output "rds_instance_ports" {
  description = "Nested map env => { accounts, ledger } => port"
  value = {
    for env in var.enabled_environments : env => {
      for svc in keys(local.app_db_services) :
      svc => module.rds.instance_ports["${env}-${svc}"]
    }
  }
}

output "rds_db_names" {
  description = "Nested map env => { accounts, ledger } => PostgreSQL database name"
  value = {
    for env in var.enabled_environments : env => {
      for svc in keys(local.app_db_services) :
      svc => module.rds.db_names["${env}-${svc}"]
    }
  }
}

output "rds_master_usernames" {
  description = "Nested map env => { accounts, ledger } => master username"
  value = {
    for env in var.enabled_environments : env => {
      for svc in keys(local.app_db_services) :
      svc => module.rds.master_usernames["${env}-${svc}"]
    }
  }
}

output "rds_master_user_secret_arns" {
  description = "Nested map env => { accounts, ledger } => Secrets Manager ARN (for ESO)"
  value = {
    for env in var.enabled_environments : env => {
      for svc in keys(local.app_db_services) :
      svc => module.rds.master_user_secret_arns["${env}-${svc}"]
    }
  }
}

output "eso_namespace" {
  description = "Namespace where External Secrets Operator runs"
  value       = module.external_secrets.namespace
}

output "eso_service_account_name" {
  description = "ESO ServiceAccount name for ClusterSecretStore IRSA reference"
  value       = module.external_secrets.service_account_name
}

output "eso_iam_role_arn" {
  description = "IAM role ARN used by ESO via IRSA"
  value       = module.external_secrets.iam_role_arn
}

output "alb_controller_namespace" {
  description = "Namespace where AWS Load Balancer Controller runs"
  value       = module.aws_load_balancer_controller.namespace
}

output "alb_controller_service_account_name" {
  description = "AWS Load Balancer Controller ServiceAccount name (IRSA)"
  value       = module.aws_load_balancer_controller.service_account_name
}

output "alb_controller_iam_role_arn" {
  description = "IAM role ARN used by AWS Load Balancer Controller via IRSA"
  value       = module.aws_load_balancer_controller.iam_role_arn
}

output "alb_controller_release_name" {
  description = "Helm release name for AWS Load Balancer Controller"
  value       = module.aws_load_balancer_controller.release_name
}

output "ingress_environments" {
  description = "App environments that receive a public frontend Ingress"
  value       = var.ingress_environments
}

output "ingress_domain" {
  description = "Public DNS zone for frontend TLS (empty = lab HTTP ALB)"
  value       = var.ingress_domain
}

output "ingress_group_name" {
  description = "ALB IngressGroup name (TLS / shared ALB only)"
  value       = local.ingress_group_name
}

output "ingress_certificate_arn" {
  description = "ACM certificate ARN injected into Argo when ingress_domain is set"
  value       = local.ingress_certificate_arn
}

output "ingress_hosted_zone_id" {
  description = "Existing Route53 public hosted zone ID looked up by ingress_domain (null when empty)"
  value       = try(module.ingress_dns[0].zone_id, null)
}

output "ingress_name_servers" {
  description = "Nameservers of the existing hosted zone (informational; already attached for a Route 53 registered domain)"
  value       = try(module.ingress_dns[0].name_servers, null)
}

output "external_dns_namespace" {
  description = "Namespace where ExternalDNS runs (null when ingress_domain is empty)"
  value       = try(module.external_dns[0].namespace, null)
}

output "external_dns_iam_role_arn" {
  description = "IAM role ARN used by ExternalDNS via IRSA (null when ingress_domain is empty)"
  value       = try(module.external_dns[0].iam_role_arn, null)
}

output "frontend_ingress" {
  description = "Per-env Ingress Helm values injected into Argo (enabled, scheme, host, certificate ARN)"
  value       = local.frontend_ingress
}

output "grafana_ingress" {
  description = "Grafana Ingress Helm values injected into Argo (host, certificate ARN, group name). Empty host = no Ingress."
  value       = local.grafana_ingress
}

output "enable_monitoring" {
  description = "Whether root-platform-monitoring is synced"
  value       = var.enable_monitoring
}

output "jwt_secret_name" {
  description = "Expected Secrets Manager name for JWT (scripts/bootstrap-jwt.ps1)"
  value       = var.jwt_secret_name
}

output "grafana_admin_secret_name" {
  description = "Expected Secrets Manager name for Grafana admin (scripts/bootstrap-grafana.ps1)"
  value       = var.grafana_admin_secret_name
}

output "argocd_namespace" {
  description = "Namespace where Argo CD runs (port-forward svc/argocd-server)"
  value       = module.argocd.namespace
}

output "argocd_app_project_name" {
  description = "AppProject name for Bank of Anthos Applications"
  value       = module.argocd.app_project_name
}

output "argocd_repo_secret_name" {
  description = "Secret with private Git credentials for Argo CD"
  value       = module.argocd.repo_secret_name
}
