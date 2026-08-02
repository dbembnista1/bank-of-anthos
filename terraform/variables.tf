variable "aws_region" {
  description = "AWS region for the core infrastructure"
  type        = string
  default     = "eu-central-1"
}

variable "environment" {
  description = "Environment tag for shared platform resources (dev/prod split is at namespace level)"
  type        = string
  default     = "shared"
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
  default     = "1.31"
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

variable "eks_node_desired_size" {
  description = "Desired size of the managed node group"
  type        = number
  default     = 2
}
