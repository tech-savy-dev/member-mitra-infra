provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "member-mitra"
      Environment = "dev"
      ManagedBy   = "terraform"
      Repo        = "tech-savy-dev/member-mitra-infra"
    }
  }
}

# CloudFront + ACM + WAFv2 (CLOUDFRONT scope) must live in us-east-1.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  default_tags {
    tags = {
      Project     = "member-mitra"
      Environment = "dev"
      ManagedBy   = "terraform"
      Repo        = "tech-savy-dev/member-mitra-infra"
    }
  }
}

# Pull VPC + DNS info from the shared stack.
data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = "REPLACE_ME_FROM_BOOTSTRAP_OUTPUT" # same bucket as backend.tf
    key    = "shared/terraform.tfstate"
    region = "ap-south-1"
  }
}

# ---------- Frontend ----------
module "frontend" {
  source = "../../modules/frontend"
  providers = {
    aws.us_east_1 = aws.us_east_1
  }
  environment    = "dev"
  primary_domain = var.primary_domain
  alt_domains    = var.alt_domains
  hosted_zone_id = data.terraform_remote_state.shared.outputs.hosted_zone_id
}

# ---------- Secrets ----------
module "secrets" {
  source      = "../../modules/secrets"
  environment = "dev"
  kms_key_arn = var.kms_key_arn
}

# ---------- Monitoring ----------
module "monitoring" {
  source                     = "../../modules/monitoring"
  environment                = "dev"
  cloudfront_distribution_id = module.frontend.cloudfront_distribution_id
  alarm_email                = var.alarm_email
}

# ---------- CI/CD pass-through ----------
module "cicd" {
  source      = "../../modules/cicd"
  environment = "dev"
}
