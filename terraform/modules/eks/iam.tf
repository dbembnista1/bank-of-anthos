# Humans assume this role for kubectl (access entry on the cluster). CI uses the
# GitHub OIDC role entry directly — no assume-role in the kubernetes/helm providers.
# Trust is the account root so forks do not hardcode an IAM user. Any principal in this
# account that is allowed sts:AssumeRole (e.g. AdministratorAccess) can assume it.

data "aws_caller_identity" "current" {}

data "aws_iam_role" "github_actions" {
  name = var.github_actions_role_name != "" ? var.github_actions_role_name : "${var.cluster_name}-github-oidc-role"
}

data "aws_iam_policy_document" "cluster_admin_assume" {
  statement {
    sid     = "AccountRootAssume"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_iam_role" "cluster_admin" {
  name               = "${var.cluster_name}-eks-admin"
  assume_role_policy = data.aws_iam_policy_document.cluster_admin_assume.json
  tags               = var.tags
}
