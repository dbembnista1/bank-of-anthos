variable "namespace" {
  description = "Namespace where External Secrets Operator is installed"
  type        = string
  default     = "external-secrets"
}

variable "release_name" {
  description = "Helm release name"
  type        = string
  default     = "external-secrets"
}

variable "chart_version" {
  description = "external-secrets Helm chart version (charts.external-secrets.io)"
  type        = string
  default     = "0.14.4"
}

variable "service_account_name" {
  description = "Kubernetes ServiceAccount name used by ESO (IRSA trust + ClusterSecretStore ref)"
  type        = string
  default     = "external-secrets"
}

variable "iam_role_name" {
  description = "IAM role name for ESO IRSA"
  type        = string
  default     = "bank-of-anthos-external-secrets"
}

variable "oidc_provider_arn" {
  description = "EKS IAM OIDC provider ARN (IRSA trust)"
  type        = string
}

variable "oidc_provider" {
  description = "EKS OIDC provider URL without https:// (IRSA trust condition keys)"
  type        = string
}

variable "secrets_manager_arns" {
  description = "Secrets Manager ARNs ESO may read (RDS master secrets + JWT pattern)"
  type        = list(string)

  validation {
    condition     = length(var.secrets_manager_arns) >= 1
    error_message = "secrets_manager_arns must include at least one ARN or ARN pattern."
  }
}

variable "tags" {
  description = "Additional tags for IAM resources"
  type        = map(string)
  default     = {}
}
