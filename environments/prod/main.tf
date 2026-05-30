provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "member-mitra"
      Environment = "prod"
      ManagedBy   = "terraform"
      Repo        = "tech-savy-dev/member-mitra-infra"
    }
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  default_tags {
    tags = {
      Project     = "member-mitra"
      Environment = "prod"
      ManagedBy   = "terraform"
      Repo        = "tech-savy-dev/member-mitra-infra"
    }
  }
}

data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = "REPLACE_ME_FROM_BOOTSTRAP_OUTPUT"
    key    = "shared/terraform.tfstate"
    region = "ap-south-1"
  }
}

module "frontend" {
  source = "../../modules/frontend"
  providers = {
    aws.us_east_1 = aws.us_east_1
  }
  environment    = "prod"
  primary_domain = var.primary_domain
  alt_domains    = var.alt_domains
  hosted_zone_id = data.terraform_remote_state.shared.outputs.hosted_zone_id
  # Tighter rate-limit in prod.
  rate_limit_per_5min = 1000
}

module "secrets" {
  source      = "../../modules/secrets"
  environment = "prod"
  kms_key_arn = var.kms_key_arn
}

module "monitoring" {
  source                     = "../../modules/monitoring"
  environment                = "prod"
  cloudfront_distribution_id = module.frontend.cloudfront_distribution_id
  alarm_email                = var.alarm_email
}

module "cicd" {
  source      = "../../modules/cicd"
  environment = "prod"
}
