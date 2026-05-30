terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.60" }
  }
}

# The OIDC role + provider are created by bootstrap (one-time, admin
# apply). This module is a thin pass-through: it data-sources the
# existing roles so env stacks can reference their ARNs in outputs.
#
# Kept as a module so a future tightening (env-scoped policies, separate
# Lambda deploy roles, etc.) lives in one place.

data "aws_iam_role" "infra" {
  name = "member-mitra-infra-${var.environment}"
}
