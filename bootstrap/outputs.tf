output "tfstate_bucket_name" {
  description = "S3 bucket for Terraform state."
  value       = aws_s3_bucket.tfstate.id
}

output "tflock_table_name" {
  description = "DynamoDB table for state locking."
  value       = aws_dynamodb_table.tflock.name
}

output "kms_key_arn" {
  description = "Shared KMS key for SSM SecureStrings + state bucket SSE."
  value       = aws_kms_key.main.arn
}

output "kms_key_alias" {
  value = aws_kms_alias.main.name
}

output "oidc_provider_arn" {
  description = "GitHub OIDC provider ARN."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "oidc_role_dev_arn" {
  description = "IAM role for GitHub Actions to assume for shared/ and dev/."
  value       = aws_iam_role.infra_dev.arn
}

output "oidc_role_prod_arn" {
  description = "IAM role for GitHub Actions to assume for prod/ (gated by environment)."
  value       = aws_iam_role.infra_prod.arn
}
