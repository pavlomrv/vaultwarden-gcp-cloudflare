terraform {
  required_version = ">= 1.15.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {
    bucket       = "tfstate-941445065143-eu-north-1-an"
    key          = "aim-user/terraform.tfstate"
    region       = "eu-north-1"
    encrypt      = true
    use_lockfile = true # Enables native S3 state locking (Terraform 1.10+)
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_organizations_account" "main" {
  name                       = var.account_name
  email                      = var.account_email
  role_name                  = var.organization_account_access_role_name
  iam_user_access_to_billing = var.iam_user_access_to_billing
  close_on_deletion          = true
  lifecycle {
    prevent_destroy = false
  }
}
