output "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "aws_region" {
  description = "AWS region deployed to"
  value       = var.aws_region
}

output "github_actions_role_arn" {
  description = "ARN of the IAM Role used by GitHub Actions (OIDC)"
  value       = aws_iam_role.github_actions.arn
}
