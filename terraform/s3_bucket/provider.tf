terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "terraform-sync-state-6395e36ea95d48ee"
    key            = "s3_bucket/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-sync-locks"
  }
}

provider "aws" {
  region = "us-east-1"
}