output "namespace" {
  description = "Namespace where External Secrets Operator runs"
  value       = helm_release.eso.namespace
}

output "release_name" {
  description = "Helm release name"
  value       = helm_release.eso.name
}

output "service_account_name" {
  description = "ServiceAccount name annotated for IRSA (use in ClusterSecretStore)"
  value       = var.service_account_name
}

output "iam_role_arn" {
  description = "IAM role ARN assumed by ESO via IRSA"
  value       = aws_iam_role.eso.arn
}

output "iam_role_name" {
  description = "IAM role name for ESO"
  value       = aws_iam_role.eso.name
}
