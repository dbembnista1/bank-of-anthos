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

  # ESO IRSA may read RDS-managed secrets + JWT secret created by scripts/bootstrap-jwt.ps1.
  # Secrets Manager ARNs include a random suffix → allow name-* for JWT.
  jwt_secret_arn_pattern = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.jwt_secret_name}-*"

  eso_secrets_manager_arns = concat(
    values(module.rds.master_user_secret_arns),
    [local.jwt_secret_arn_pattern]
  )
}
