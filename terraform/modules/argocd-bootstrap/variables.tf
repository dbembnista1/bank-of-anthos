variable "namespace" {
  description = "Namespace where Argo CD is installed"
  type        = string
  default     = "argocd"
}

variable "chart_version" {
  description = "argo-cd Helm chart version (argo-helm). 9.4.13 ships Argo CD v3.3.4 (K8s 1.33+ OpenAPI schema)."
  type        = string
  default     = "9.4.13"
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

variable "gitops_app_paths" {
  description = "Map of enabled environment name => repo path with Application manifests"
  type        = map(string)
}

variable "enabled_environments" {
  description = "App environments that get a root App-of-Apps (must match keys in gitops_app_paths)"
  type        = list(string)
}

variable "destination_namespaces" {
  description = "Kubernetes namespaces AppProject may deploy into (plus argocd for App-of-Apps)"
  type        = list(string)
}

variable "gitops_platform_external_secrets_path" {
  description = "Repo path with ClusterSecretStore Helm chart"
  type        = string
  default     = "gitops/platform/external-secrets"
}

variable "external_secrets_namespace" {
  description = "Destination namespace for the platform External Secrets App-of-Apps (ESO operator ns)"
  type        = string
  default     = "external-secrets"
}

variable "enable_monitoring" {
  description = "Create root-platform-monitoring (kube-prometheus-stack GitOps). Off = no Application, no monitoring or kube-system destinations."
  type        = bool
  default     = false
}

variable "gitops_platform_monitoring_path" {
  description = "Repo path with kube-prometheus-stack wrapper chart"
  type        = string
  default     = "gitops/platform/monitoring"
}

variable "monitoring_namespace" {
  description = "Destination namespace for root-platform-monitoring"
  type        = string
  default     = "monitoring"
}

variable "grafana_ingress" {
  description = "Grafana Ingress Helm parameters (host, ACM ARN, ALB group). Empty host = lab, no Ingress."
  type = object({
    host            = string
    certificate_arn = string
    group_name      = string
  })
  default = {
    host            = ""
    certificate_arn = ""
    group_name      = "bank-of-anthos"
  }
}

variable "database_hosts" {
  description = "Map of env => { accounts, ledger } RDS hostnames injected into App-of-Apps Helm parameters"
  type = map(object({
    accounts = string
    ledger   = string
  }))
  default = {}
}

variable "database_secret_arns" {
  description = "Map of env => { accounts, ledger } RDS-managed Secrets Manager ARNs for ExternalSecret remoteRef (not secret payloads)"
  type = map(object({
    accounts = string
    ledger   = string
  }))
  default = {}
}

variable "image_registry" {
  description = "ECR registry URL injected into App-of-Apps Helm parameters (global.imageRegistry)"
  type        = string
}

variable "frontend_ingress" {
  description = "Per-env frontend Ingress Helm parameters injected into root App-of-Apps (enabled, scheme, host, ACM ARN). Host and certificate_arn are empty in lab mode."
  type = map(object({
    enabled         = bool
    scheme          = string
    host            = string
    certificate_arn = string
  }))
}
