# Dynamically fetch the thumbprint from GitHub's OIDC endpoint
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

# Trust policy: only allow assume role from this specific GitHub repository
data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Restrict to this repository. GitHub now prefixes sub with owner/repo numeric IDs
    # (repo:owner@id/repo@id:ref:...) as well as the classic repo:owner/repo:ref:... form.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_owner}/${var.github_repo_name}:*",
        "repo:${var.github_owner}@*/${var.github_repo_name}@*:*",
      ]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.project_name}-github-oidc-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
}

# AdministratorAccess is standard for CI/CD pipelines deploying full IaC stacks.
resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ---------------------------------------------------------------------------------------------------------------------
# GITHUB SECRETS & VARIABLES — push all CI/CD config directly to the repository
# ---------------------------------------------------------------------------------------------------------------------

# IAM role ARN used by all workflows for OIDC authentication
resource "github_actions_secret" "aws_oidc_role_arn" {
  repository      = var.github_repo_name
  secret_name     = "AWS_OIDC_ROLE_ARN"
  plaintext_value = aws_iam_role.github_actions.arn
}

# GitHub PAT for TF_VAR_argocd_gh_token in terraform-plan.yaml / terraform-apply.yaml.
# PR plan comments use GITHUB_TOKEN, not this secret.
resource "github_actions_secret" "gh_pat" {
  count           = var.github_token != null ? 1 : 0
  repository      = var.github_repo_name
  secret_name     = "GH_PAT"
  plaintext_value = var.github_token
}

# Backend config — terraform-plan.yaml and terraform-apply.yaml write backend.conf
# from these variables so the bucket name is not hardcoded in Git.
resource "github_actions_variable" "tf_state_bucket" {
  repository    = var.github_repo_name
  variable_name = "TF_STATE_BUCKET"
  value         = aws_s3_bucket.terraform_state.bucket
}

resource "github_actions_variable" "tf_state_dynamodb_table" {
  repository    = var.github_repo_name
  variable_name = "TF_STATE_DYNAMODB_TABLE"
  value         = aws_dynamodb_table.terraform_locks.name
}

resource "github_actions_variable" "aws_region" {
  repository    = var.github_repo_name
  variable_name = "AWS_REGION"
  value         = var.aws_region
}
