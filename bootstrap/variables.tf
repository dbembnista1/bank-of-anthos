variable "project_name" {
  description = "Prefix used for naming all resources"
  type        = string
  default     = "bank-of-anthos"
}

variable "owner" {
  description = "Value for the Owner tag (cost and security auditor)"
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to all resources (Owner is merged from var.owner)"
  type        = map(string)
  default = {
    Project     = "BankOfAnthos"
    Environment = "Bootstrap"
    ManagedBy   = "Terraform"
  }
}

variable "aws_region" {
  description = "AWS region for the bootstrap resources"
  type        = string
  default     = "eu-central-1"
}

variable "aws_profile" {
  description = "AWS CLI profile to use for authentication (e.g. default, bank)"
  type        = string
  default     = "default"
}

variable "github_owner" {
  description = "GitHub username or organization name (e.g. my-org)"
  type        = string
}

variable "github_repo_name" {
  description = "GitHub repository name without owner (e.g. aws-eks-bank-of-anthos)"
  type        = string
}

variable "github_token" {
  description = "GitHub Personal Access Token with repo scope. Pass via: $env:TF_VAR_github_token — never store in tfvars."
  type        = string
  default     = null
  sensitive   = true
}
