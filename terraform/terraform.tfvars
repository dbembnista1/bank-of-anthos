# Committed knobs for this stack (laptop and GHA use the same file).
# No secrets here. Argo PAT: $env:TF_VAR_argocd_gh_token = "ghp_..."

aws_region  = "eu-central-1"
environment = "shared"
project     = "BankOfAnthos"
owner       = "dawid"

# App environments: RDS + Argo roots (shared VPC/EKS always on)
enabled_environments = ["dev"]

# VPC (defaults match a 2-AZ layout in eu-central-1)
vpc_name             = "bank-of-anthos"
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["eu-central-1a", "eu-central-1b"]
public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
enable_nat_gateway   = true
single_nat_gateway   = true

# EKS (shared cluster; app envs are namespaces bank-of-anthos-<env>)
eks_cluster_name            = "bank-of-anthos"
eks_cluster_version         = "1.35"
eks_endpoint_public_access  = true
eks_endpoint_private_access = true
eks_node_instance_types     = ["t3.medium"]
eks_node_min_size           = 2
eks_node_max_size           = 4

# kube-prometheus-stack via GitOps (root-platform-monitoring) + extra node at create.
# Grafana Ingress: boa-grafana.dbembnista.com on the shared ALB (ingress_domain is set).
# Admin password: .\scripts\bootstrap-grafana.ps1 (SM name = grafana_admin_secret_name).
enable_monitoring = true

# ECR (app images only; DBs are on RDS)
# ecr_repository_names defaults cover all 7 Bank of Anthos services
ecr_lifecycle_keep_last = 10
ecr_force_delete        = true

# RDS (PostgreSQL — accounts + ledger per enabled environment; passwords in Secrets Manager)
rds_name_prefix             = "bank-of-anthos"
rds_engine_version          = "16.14"
rds_instance_class          = "db.t4g.micro"
rds_allocated_storage       = 20
rds_max_allocated_storage   = 0
rds_multi_az                = false
rds_backup_retention_period = 1
rds_deletion_protection     = false
rds_skip_final_snapshot     = true

# Argo CD (bootstrap via Helm; root Apps only for enabled_environments)
# Set the PAT in the shell — never put it in this file or commit it:
#   $env:TF_VAR_argocd_gh_token = "ghp_..."
argocd_repo_url = "https://github.com/dbembnista1/bank-of-anthos.git"
# Git revision Argo syncs (root + child Applications). Default main.
# To test a PR branch: push it, set this to the branch name, terraform apply.
# After merge: set back to main and apply — otherwise Argo keeps tracking a deleted branch.
argocd_target_revision = "main"
# argocd_chart_version and argocd_apps_chart_version use module defaults unless overridden

# Public Ingress (injected into Argo; not set in Helm overlays)
# Domain registered in this account (Route 53).
#   frontend: boa-dev.dbembnista.com
#   Grafana:  boa-grafana.dbembnista.com (same ALB, when enable_monitoring is true)
ingress_environments = ["dev"]
ingress_domain       = "dbembnista.com"
