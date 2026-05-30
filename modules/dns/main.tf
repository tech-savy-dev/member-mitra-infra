terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.60" }
  }
}

# Route53 hosted zone for the whole project. One zone, both envs share it.
# Records for env-specific subdomains live in modules/frontend (per env).
resource "aws_route53_zone" "main" {
  name    = var.domain_name
  comment = "MemberMitra primary hosted zone — managed by Terraform"
}
