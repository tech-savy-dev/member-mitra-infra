terraform {
  required_version = ">= 1.7"

  # Replace bucket + dynamodb_table with the real names emitted by
  # bootstrap (terraform output -json). Until then, this file is a
  # template — `terraform init` will fail loudly without the real
  # values, which is what we want.
  backend "s3" {
    bucket         = "REPLACE_ME_FROM_BOOTSTRAP_OUTPUT" # tfstate_bucket_name
    key            = "shared/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "member-mitra-tflock"
    encrypt        = true
  }

  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.60" }
  }
}
