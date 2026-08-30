variable "aws_region" {
  description = "AWS region for the core infrastructure"
  type        = string
  default     = "eu-central-1"
}

variable "environment" {
  description = "Environment tag for shared platform resources (VPC/EKS); app envs are var.enabled_environments"
  type        = string
  default     = "shared"
}

variable "enabled_environments" {
  description = "App environments to provision (RDS + Argo root Apps). Shared EKS/VPC always exist. Default: dev only (FinOps)."
  type        = list(string)
  default     = ["dev"]

  validation {
    condition = alltrue([
      for env in var.enabled_environments : contains(["dev", "prod"], env)
    ])
    error_message = "enabled_environments may only contain \"dev\" and/or \"prod\"."
  }

  validation {
    condition     = length(var.enabled_environments) >= 1
    error_message = "enabled_environments must include at least one environment."
  }

  validation {
    condition     = length(var.enabled_environments) == length(toset(var.enabled_environments))
    error_message = "enabled_environments must not contain duplicates."
  }
}

variable "owner" {
  description = "Value for the Owner tag (cost and security auditor)"
  type        = string
}

variable "project" {
  description = "Value for the Project tag (cost and security auditor)"
  type        = string
  default     = "BankOfAnthos"
}

variable "common_tags" {
  description = "Extra tags merged into default_tags (Owner/Project/Environment are set separately)"
  type        = map(string)
  default     = {}
}

variable "vpc_name" {
  description = "Name prefix for VPC resources"
  type        = string
  default     = "bank-of-anthos"
}

variable "vpc_cidr" {
  description = "CIDR block for the shared VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for subnets (minimum 2 for EKS)"
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "enable_nat_gateway" {
  description = "Create NAT Gateway(s) so private subnets can reach the internet"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use one NAT Gateway for all AZs (lower cost). Set false for NAT per AZ"
  type        = bool
  default     = true
}

variable "eks_cluster_name" {
  description = "Name of the shared EKS cluster (dev/prod separated by namespaces)"
  type        = string
  default     = "bank-of-anthos"
}

variable "eks_cluster_version" {
  description = "Kubernetes version for the EKS control plane"
  type        = string
  default     = "1.35"
}

variable "eks_endpoint_public_access" {
  description = "Allow public access to the Kubernetes API (local kubectl); private access stays enabled"
  type        = bool
  default     = true
}

variable "eks_endpoint_private_access" {
  description = "Allow private VPC access to the Kubernetes API"
  type        = bool
  default     = true
}

variable "eks_node_instance_types" {
  description = "EC2 instance types for the managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_node_min_size" {
  description = "Minimum size of the managed node group"
  type        = number
  default     = 2
}

variable "eks_node_max_size" {
  description = "Maximum size of the managed node group"
  type        = number
  default     = 4
}

variable "ecr_repository_names" {
  description = "ECR repos for Bank of Anthos app images (ledger-db/accounts-db use RDS, not container images)"
  type        = list(string)
  default = [
    "bank-of-anthos/frontend",
    "bank-of-anthos/ledgerwriter",
    "bank-of-anthos/balancereader",
    "bank-of-anthos/transactionhistory",
    "bank-of-anthos/userservice",
    "bank-of-anthos/contacts",
    "bank-of-anthos/loadgenerator",
  ]
}

variable "ecr_lifecycle_keep_last" {
  description = "Keep the last N images per repository; expire older ones"
  type        = number
  default     = 10
}

variable "ecr_force_delete" {
  description = "Allow destroying non-empty ECR repos (lab teardown)"
  type        = bool
  default     = true
}

variable "rds_name_prefix" {
  description = "Prefix for RDS subnet group and security group names"
  type        = string
  default     = "bank-of-anthos"
}

variable "rds_engine_version" {
  description = "PostgreSQL engine version for all RDS instances"
  type        = string
  default     = "16.14"
}

variable "rds_instance_class" {
  description = "RDS instance class (db.t4g.micro for lab FinOps)"
  type        = string
  default     = "db.t4g.micro"
}

variable "rds_allocated_storage" {
  description = "Allocated storage in GiB per instance"
  type        = number
  default     = 20
}

variable "rds_max_allocated_storage" {
  description = "Storage autoscaling upper limit in GiB (0 = disabled)"
  type        = number
  default     = 0
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ for RDS (higher cost; default false for lab)"
  type        = bool
  default     = false
}

variable "rds_backup_retention_period" {
  description = "Days to retain automated backups"
  type        = number
  default     = 1
}

variable "rds_deletion_protection" {
  description = "Prevent accidental RDS deletion (disable for lab teardown)"
  type        = bool
  default     = false
}

variable "rds_skip_final_snapshot" {
  description = "Skip final snapshot on destroy (lab teardown convenience)"
  type        = bool
  default     = true
}

variable "jwt_secret_name" {
  description = "Secrets Manager name used by scripts/bootstrap-jwt.ps1 (IRSA ARN pattern for ESO)"
  type        = string
  default     = "bank-of-anthos-jwt"
}

variable "eso_namespace" {
  description = "Namespace for External Secrets Operator"
  type        = string
  default     = "external-secrets"
}

variable "eso_chart_version" {
  description = "external-secrets Helm chart version"
  type        = string
  default     = "0.17.0"
}

variable "eso_service_account_name" {
  description = "ESO ServiceAccount name (IRSA + ClusterSecretStore serviceAccountRef)"
  type        = string
  default     = "external-secrets"
}

variable "eso_iam_role_name" {
  description = "IAM role name for External Secrets Operator IRSA"
  type        = string
  default     = "bank-of-anthos-external-secrets"
}

variable "alb_controller_namespace" {
  description = "Namespace for AWS Load Balancer Controller"
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "alb_controller_chart_version" {
  description = "aws-load-balancer-controller Helm chart version (aws.github.io/eks-charts)"
  type        = string
  default     = "3.5.0"
}

variable "alb_controller_service_account_name" {
  description = "AWS Load Balancer Controller ServiceAccount name (IRSA trust + Helm SA)"
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "alb_controller_iam_role_name" {
  description = "IAM role name for AWS Load Balancer Controller IRSA"
  type        = string
  default     = "bank-of-anthos-aws-lbc"
}

variable "argocd_repo_url" {
  description = "Git repository URL for Argo CD App-of-Apps and child Applications"
  type        = string
  default     = "https://github.com/dbembnista1/bank-of-anthos.git"
}

variable "argocd_gh_username" {
  description = "GitHub username for Argo CD HTTPS clone (x-access-token with a PAT)"
  type        = string
  default     = "x-access-token"
}

variable "argocd_gh_token" {
  description = "GitHub PAT (contents:read) for private repo access. Set via TF_VAR_argocd_gh_token — do not commit."
  type        = string
  sensitive   = true
}

variable "argocd_target_revision" {
  description = "Git revision synced by root App-of-Apps"
  type        = string
  default     = "main"
}

variable "argocd_chart_version" {
  description = "argo-cd Helm chart version"
  type        = string
  default     = "7.8.14"
}

variable "argocd_apps_chart_version" {
  description = "argocd-apps Helm chart version (AppProject + root Applications)"
  type        = string
  default     = "2.0.2"
}
