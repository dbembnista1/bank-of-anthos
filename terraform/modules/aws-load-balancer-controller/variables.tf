variable "cluster_name" {
  description = "EKS cluster name (required by the controller to tag and discover AWS resources)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the cluster (avoids IMDS lookup from controller pods)"
  type        = string
}

variable "region" {
  description = "AWS region of the EKS cluster"
  type        = string
}

variable "namespace" {
  description = "Namespace where AWS Load Balancer Controller is installed"
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "release_name" {
  description = "Helm release name"
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "chart_version" {
  description = "aws-load-balancer-controller Helm chart version (aws.github.io/eks-charts)"
  type        = string
  default     = "3.5.0"
}

variable "service_account_name" {
  description = "Kubernetes ServiceAccount name used by the controller (IRSA trust must match)"
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "iam_role_name" {
  description = "IAM role name for AWS Load Balancer Controller IRSA"
  type        = string
  default     = "bank-of-anthos-aws-lbc"
}

variable "oidc_provider_arn" {
  description = "EKS IAM OIDC provider ARN (IRSA trust)"
  type        = string
}

variable "tags" {
  description = "Additional tags for IAM resources"
  type        = map(string)
  default     = {}
}
