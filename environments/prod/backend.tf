terraform {
  required_version = ">= 1.7"

  backend "s3" {
    bucket         = "REPLACE_ME_FROM_BOOTSTRAP_OUTPUT" # tfstate_bucket_name
    key            = "environments/prod/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "member-mitra-tflock"
    encrypt        = true
  }

  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.60" }
  }
}
