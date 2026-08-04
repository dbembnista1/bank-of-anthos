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

  # Kubernetes namespaces for enabled app environments (Argo destinations).
  app_namespaces = [
    for env in var.enabled_environments : "bank-of-anthos-${env}"
  ]

  gitops_app_paths = {
    for env in var.enabled_environments :
    env => "gitops/apps/${env}"
  }
}
