locals {
  # DB roles provisioned for each enabled app environment (accounts + ledger).
  app_db_services = {
    accounts = {
      db_name  = "accounts_db"
      username = "accounts_admin"
    }
    ledger = {
      db_name  = "ledger_db"
      username = "ledger_admin"
    }
  }

  # Flat map for the RDS module: "dev-accounts", "prod-ledger", ...
  rds_instances = {
    for pair in setproduct(var.enabled_environments, keys(local.app_db_services)) :
    "${pair[0]}-${pair[1]}" => {
      env        = pair[0]
      service    = pair[1]
      identifier = "${var.rds_name_prefix}-${pair[0]}-${pair[1]}"
      db_name    = local.app_db_services[pair[1]].db_name
      username   = local.app_db_services[pair[1]].username
    }
  }

  # Kubernetes namespaces for enabled app environments + ESO (ClusterSecretStore App destination).
  app_namespaces = [
    for env in var.enabled_environments : "bank-of-anthos-${env}"
  ]

  argocd_destination_namespaces = concat(
    local.app_namespaces,
    [var.eso_namespace]
  )

  gitops_app_paths = {
    for env in var.enabled_environments :
    env => "gitops/apps/${env}"
  }

  # Shared ECR registry for all app images (account.dkr.ecr.region.amazonaws.com).
  # Injected into Argo like RDS hosts — Git keeps a placeholder, not the account ID.
  ecr_image_registry = "${module.ecr.registry_id}.dkr.ecr.${var.aws_region}.amazonaws.com"

  # Nested maps for Argo Helm parameter injection (hosts + RDS-managed secret ARNs).
  # Passwords stay in Secrets Manager only — Terraform never reads secret payloads.
  database_hosts = {
    for env in var.enabled_environments :
    env => {
      accounts = module.rds.instance_endpoints["${env}-accounts"]
      ledger   = module.rds.instance_endpoints["${env}-ledger"]
    }
  }

  database_secret_arns = {
    for env in var.enabled_environments :
    env => {
      accounts = module.rds.master_user_secret_arns["${env}-accounts"]
      ledger   = module.rds.master_user_secret_arns["${env}-ledger"]
    }
  }

  # ESO IRSA: JWT (bootstrap script) + RDS-managed master secrets (ARN only in state).
  jwt_secret_arn_pattern = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.jwt_secret_name}-*"

  eso_secrets_manager_arns = concat(
    values(module.rds.master_user_secret_arns),
    [local.jwt_secret_arn_pattern]
  )
}
