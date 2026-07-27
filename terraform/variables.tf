variable "aws_region" {
  description = "AWS region for the core infrastructure"
  type        = string
  default     = "eu-central-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "core"
}
