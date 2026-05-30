output "s3_bucket_name" {
  value = module.frontend.s3_bucket_name
}

output "cloudfront_distribution_id" {
  value = module.frontend.cloudfront_distribution_id
}

output "cloudfront_domain_name" {
  value = module.frontend.cloudfront_domain_name
}

output "primary_domain" {
  value = var.primary_domain
}

output "ssm_parameter_names" {
  value = module.secrets.parameter_names
}

output "github_actions_role_arn" {
  value = module.cicd.github_actions_role_arn
}
