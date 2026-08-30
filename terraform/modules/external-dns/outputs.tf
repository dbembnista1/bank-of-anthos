output "namespace" {
  description = "Namespace where ExternalDNS runs"
  value       = helm_release.this.namespace
}

output "release_name" {
  description = "Helm release name"
  value       = helm_release.this.name
}

output "service_account_name" {
  description = "ServiceAccount name annotated for IRSA"
  value       = var.service_account_name
}

output "iam_role_arn" {
  description = "IAM role ARN assumed by ExternalDNS via IRSA"
  value       = module.irsa.iam_role_arn
}
