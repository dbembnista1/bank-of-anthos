data "aws_iam_policy_document" "irsa_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }
  }
}

data "aws_iam_policy_document" "secrets_manager_read" {
  statement {
    sid    = "ReadAllowedSecrets"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = var.secrets_manager_arns
  }
}

resource "aws_iam_role" "eso" {
  name               = var.iam_role_name
  assume_role_policy = data.aws_iam_policy_document.irsa_assume.json
  tags = merge(var.tags, {
    Name = var.iam_role_name
  })
}

resource "aws_iam_role_policy" "eso_secrets" {
  name   = "${var.iam_role_name}-secretsmanager"
  role   = aws_iam_role.eso.id
  policy = data.aws_iam_policy_document.secrets_manager_read.json
}

# Official chart: https://charts.external-secrets.io — chart name external-secrets
resource "helm_release" "eso" {
  name             = var.release_name
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true
  wait             = true
  atomic           = true
  timeout          = 600

  values = [
    yamlencode({
      installCRDs = true
      serviceAccount = {
        create = true
        name   = var.service_account_name
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.eso.arn
        }
      }
    })
  ]

  depends_on = [aws_iam_role_policy.eso_secrets]
}
