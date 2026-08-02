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

output "rds_security_group_id" {
  description = "Security group ID for RDS instances"
  value       = module.rds.security_group_id
}

output "rds_instance_endpoints" {
  description = "Map of logical DB name => endpoint hostname (for Helm values)"
  value       = module.rds.instance_endpoints
}

output "rds_instance_ports" {
  description = "Map of logical DB name => port"
  value       = module.rds.instance_ports
}

output "rds_db_names" {
  description = "Map of logical DB name => PostgreSQL database name"
  value       = module.rds.db_names
}

output "rds_master_usernames" {
  description = "Map of logical DB name => master username"
  value       = module.rds.master_usernames
}

output "rds_master_user_secret_arns" {
  description = "Map of logical DB name => Secrets Manager ARN (managed master password; for ESO)"
  value       = module.rds.master_user_secret_arns
}
