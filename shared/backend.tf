terraform {
  required_version = ">= 1.7"

  # Replace bucket + dynamodb_table with the real names emitted by
  # bootstrap (terraform output -json). Until then, this file is a
  # template — `terraform init` will fail loudly without the real
  # values, which is what we want.
  backend "s3" {
    bucket         = "member-mitra-tfstate-62dc6b00"
    key            = "shared/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "member-mitra-tflock"
    encrypt        = true
  }

  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.60" }
  }
}
