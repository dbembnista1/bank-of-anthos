# IRSA role + official LBC IAM policy. Policy JSON is large and versioned with
# the community module — we do not copy it into this repo.
module "irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.52"

  role_name                              = var.iam_role_name
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["${var.namespace}:${var.service_account_name}"]
    }
  }

  tags = var.tags
}

# Official chart: https://aws.github.io/eks-charts — chart name aws-load-balancer-controller
resource "helm_release" "this" {
  name             = var.release_name
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true
  wait             = true
  atomic           = true
  timeout          = 600

  values = [
    yamlencode({
      clusterName = var.cluster_name
      region      = var.region
      vpcId       = var.vpc_id
      # VPC CNI: register pod IPs, not node instances (Ingress annotation still sets this too).
      defaultTargetType = "ip"
      # Default webhook mutates every Service CREATE (failurePolicy=Fail). We only
      # expose the app via Ingress; ClusterIP Services (Argo CD, ESO) must not wait
      # on this webhook — it races Helm installs while controller endpoints are empty.
      enableServiceMutatorWebhook = false
      serviceAccount = {
        create = true
        name   = var.service_account_name
        annotations = {
          "eks.amazonaws.com/role-arn" = module.irsa.iam_role_arn
        }
      }
    })
  ]

  depends_on = [module.irsa]
}
