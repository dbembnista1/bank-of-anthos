output "namespace" {
  description = "Namespace where Argo CD is installed"
  value       = helm_release.argocd.namespace
}

output "release_name" {
  description = "Helm release name for the argo-cd chart"
  value       = helm_release.argocd.name
}

output "app_project_name" {
  description = "AppProject name used by root and child Applications"
  value       = var.app_project_name
}

output "repo_secret_name" {
  description = "Secret name holding private Git repo credentials for Argo CD"
  value       = kubernetes_secret_v1.repo.metadata[0].name
}
