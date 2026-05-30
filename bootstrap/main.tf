terraform {
  required_version = ">= 1.7"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.60" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "member-mitra"
      Environment = "shared"
      ManagedBy   = "terraform"
      Repo        = "${var.github_org}/${var.infra_repo}"
      Module      = "bootstrap"
    }
  }
}

# Random suffix so bucket names stay globally unique even across re-bootstraps.
resource "random_id" "suffix" {
  byte_length = 4
}

# ---------------------------------------------------------------------------
# KMS — encrypts the state bucket + SSM SecureStrings.
# ---------------------------------------------------------------------------
resource "aws_kms_key" "main" {
  description             = "member-mitra shared KMS — state + SSM SecureStrings"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

resource "aws_kms_alias" "main" {
  name          = "alias/member-mitra-shared"
  target_key_id = aws_kms_key.main.key_id
}

# ---------------------------------------------------------------------------
# S3 state bucket — versioned + encrypted + private.
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "tfstate" {
  bucket        = "member-mitra-tfstate-${random_id.suffix.hex}"
  force_destroy = false
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.main.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    id     = "expire-old-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration { noncurrent_days = 90 }
  }
}

# ---------------------------------------------------------------------------
# DynamoDB lock table.
# ---------------------------------------------------------------------------
resource "aws_dynamodb_table" "tflock" {
  name         = "member-mitra-tflock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}

# ---------------------------------------------------------------------------
# GitHub OIDC provider — single per account.
# ---------------------------------------------------------------------------
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

# ---------------------------------------------------------------------------
# IAM roles — dev + prod, assumable only via OIDC from this exact repo.
# Trust scope: dev allows ANY PR or main; prod requires GitHub Environment.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "trust_dev" {
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
    # Dev role: any PR or the main branch of this repo.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_org}/${var.infra_repo}:pull_request",
        "repo:${var.github_org}/${var.infra_repo}:ref:refs/heads/main",
        "repo:${var.github_org}/${var.infra_repo}:environment:dev",
      ]
    }
  }
}

data "aws_iam_policy_document" "trust_prod" {
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
    # Prod role: ONLY via the "production" GitHub Environment.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.infra_repo}:environment:production"]
    }
  }
}

resource "aws_iam_role" "infra_dev" {
  name               = "member-mitra-infra-dev"
  assume_role_policy = data.aws_iam_policy_document.trust_dev.json
}

resource "aws_iam_role" "infra_prod" {
  name               = "member-mitra-infra-prod"
  assume_role_policy = data.aws_iam_policy_document.trust_prod.json
}

# Broad managed policies for V1. Tighten with custom least-privilege
# policies once the resource inventory settles.
resource "aws_iam_role_policy_attachment" "dev_power" {
  role       = aws_iam_role.infra_dev.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_role_policy_attachment" "prod_power" {
  role       = aws_iam_role.infra_prod.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# PowerUser excludes IAM; grant a narrow IAM policy for the few IAM
# resources our modules create (CloudFront OAC service role, CloudWatch
# Logs delivery roles, etc.).
data "aws_iam_policy_document" "iam_limited" {
  statement {
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:GetRole",
      "iam:UpdateRole", "iam:UpdateAssumeRolePolicy",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy",
      "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy",
      "iam:ListRolePolicies", "iam:ListAttachedRolePolicies",
      "iam:PassRole", "iam:TagRole", "iam:UntagRole",
      "iam:ListInstanceProfilesForRole",
    ]
    resources = ["arn:aws:iam::*:role/member-mitra-*"]
  }
  statement {
    actions   = ["iam:ListRoles", "iam:GetPolicy", "iam:GetPolicyVersion", "iam:ListPolicies"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "iam_limited" {
  name   = "member-mitra-infra-iam-limited"
  policy = data.aws_iam_policy_document.iam_limited.json
}

resource "aws_iam_role_policy_attachment" "dev_iam" {
  role       = aws_iam_role.infra_dev.name
  policy_arn = aws_iam_policy.iam_limited.arn
}

resource "aws_iam_role_policy_attachment" "prod_iam" {
  role       = aws_iam_role.infra_prod.name
  policy_arn = aws_iam_policy.iam_limited.arn
}
