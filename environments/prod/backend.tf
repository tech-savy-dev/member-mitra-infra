terraform {
  required_version = ">= 1.7"

  backend "s3" {
    bucket         = "member-mitra-tfstate-62dc6b00"
    key            = "environments/prod/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "member-mitra-tflock"
    encrypt        = true
  }

  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.60" }
  }
}
