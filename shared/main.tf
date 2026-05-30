provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "member-mitra"
      Environment = "shared"
      ManagedBy   = "terraform"
      Repo        = "tech-savy-dev/member-mitra-infra"
    }
  }
}

module "vpc" {
  source     = "../modules/vpc"
  aws_region = var.aws_region
  cidr_block = "10.0.0.0/16"
}

module "dns" {
  source      = "../modules/dns"
  domain_name = var.domain_name
}
