terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.60" }
  }
}

# SSM Parameter Store SecureStrings.
#
# Terraform creates the parameter SLOT with a placeholder value. The real
# secret is written out-of-band via:
#   aws ssm put-parameter --name <name> --value <secret> --type SecureString --overwrite
#
# Terraform IGNORES future value changes so out-of-band writes don't show
# as drift on every plan.

locals {
  prefix = "/membermitra/${var.environment}"

  # Default set of secret slots V1 needs.
  default_secrets = [
    "supabase/url",
    "supabase/anon_key",
    "supabase/service_role_key",
    "resend/api_key",
    "razorpay/key_id",
    "razorpay/key_secret",
    "razorpay/webhook_secret",
    "aisensy/api_key",
  ]

  secrets = toset(concat(local.default_secrets, var.extra_secrets))
}

resource "aws_ssm_parameter" "secret" {
  for_each = local.secrets

  name        = "${local.prefix}/${each.value}"
  type        = "SecureString"
  key_id      = var.kms_key_arn
  value       = "PLACEHOLDER_SET_VIA_AWS_CLI"
  description = "Set the real value via: aws ssm put-parameter --name ${local.prefix}/${each.value} --type SecureString --value <secret> --overwrite"

  lifecycle {
    ignore_changes = [value]
  }
}
