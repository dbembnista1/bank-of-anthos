# Humans and CI assume this role for kubectl; EKS access entries land in a later commit.
# Trust is the account root so forks do not hardcode an IAM user. Any principal in this
# account that is allowed sts:AssumeRole (e.g. AdministratorAccess) can assume it.

data "aws_caller_identity" "current" {}

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
