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
