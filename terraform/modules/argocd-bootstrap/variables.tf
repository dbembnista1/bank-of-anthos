variable "namespace" {
  description = "Namespace where Argo CD is installed"
  type        = string
  default     = "argocd"
}

variable "chart_version" {
  description = "argo-cd Helm chart version (argo-helm)"
  type        = string
  default     = "7.8.14"
}

variable "apps_chart_version" {
  description = "argocd-apps Helm chart version (AppProject + root Applications)"
  type        = string
  default     = "2.0.2"
}

variable "repo_url" {
  description = "Git repository URL Argo CD syncs from (private; credentials via gh_token)"
  type        = string
}

variable "target_revision" {
  description = "Git revision for root App-of-Apps (branch or tag)"
  type        = string
  default     = "main"
}

variable "gh_username" {
  description = "GitHub username for HTTPS clone (use x-access-token with a PAT)"
  type        = string
  default     = "x-access-token"
}

variable "gh_token" {
  description = "GitHub PAT with contents:read (set via TF_VAR_argocd_gh_token)"
  type        = string
  sensitive   = true
}

variable "app_project_name" {
  description = "Argo CD AppProject name for Bank of Anthos Applications"
  type        = string
  default     = "bank-of-anthos"
}

variable "gitops_dev_path" {
  description = "Repo path with Application manifests for the dev environment"
  type        = string
  default     = "gitops/apps/dev"
}

variable "gitops_prod_path" {
  description = "Repo path with Application manifests for the prod environment"
  type        = string
  default     = "gitops/apps/prod"
}

variable "destination_namespaces" {
  description = "Kubernetes namespaces AppProject may deploy into (plus argocd for App-of-Apps)"
  type        = list(string)
  default     = ["bank-of-anthos-dev", "bank-of-anthos-prod"]
}
