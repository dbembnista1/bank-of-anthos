# IRSA: community module ships the Route 53 policy; we scope it to one zone.
module "irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.52"

  role_name                     = var.iam_role_name
  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = [var.hosted_zone_arn]

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["${var.namespace}:${var.service_account_name}"]
    }
  }

  tags = var.tags
}

# Official chart: https://kubernetes-sigs.github.io/external-dns/
resource "helm_release" "this" {
  name             = var.release_name
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  chart            = "external-dns"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true
  wait             = true
  atomic           = true
  timeout          = 600

  values = [
    yamlencode({
      provider = {
        name = "aws"
      }
      sources       = ["ingress"]
      policy        = "sync"
      txtOwnerId    = var.txt_owner_id
      domainFilters = [var.domain]
      extraArgs = {
        "aws-zone-type"  = "public"
        "zone-id-filter" = var.hosted_zone_id
      }
      env = [
        {
          name  = "AWS_DEFAULT_REGION"
          value = var.region
        }
      ]
      serviceAccount = {
        create = true
        name   = var.service_account_name
        annotations = {
          "eks.amazonaws.com/role-arn" = module.irsa.iam_role_arn
        }
      }
      resources = {
        requests = {
          cpu    = "50m"
          memory = "64Mi"
        }
        limits = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }
    })
  ]

  depends_on = [module.irsa]
}
