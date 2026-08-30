variable "domain" {
  description = "Public hosted zone name to manage (domainFilters). Must match the existing Route 53 zone."
  type        = string
}

variable "hosted_zone_arn" {
  description = "ARN of the public hosted zone (IRSA policy is scoped to this zone only)"
  type        = string
}

variable "hosted_zone_id" {
  description = "ID of the public hosted zone (--zone-id-filter; same zone as hosted_zone_arn)"
  type        = string
}

variable "region" {
  description = "AWS region for the AWS SDK in the controller (Route 53 is global; still required)"
  type        = string
}

variable "txt_owner_id" {
  description = "TXT registry owner id so this cluster does not steal another ExternalDNS instance's records"
  type        = string
}

variable "namespace" {
  description = "Namespace where ExternalDNS is installed"
  type        = string
  default     = "external-dns"
}

variable "release_name" {
  description = "Helm release name"
  type        = string
  default     = "external-dns"
}

variable "chart_version" {
  description = "external-dns Helm chart version (kubernetes-sigs.github.io/external-dns)"
  type        = string
  default     = "1.21.1"
}

variable "service_account_name" {
  description = "Kubernetes ServiceAccount name (IRSA trust must match)"
  type        = string
  default     = "external-dns"
}

variable "iam_role_name" {
  description = "IAM role name for ExternalDNS IRSA"
  type        = string
  default     = "bank-of-anthos-external-dns"
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
