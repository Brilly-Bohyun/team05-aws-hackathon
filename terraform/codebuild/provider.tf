terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "terraform-sync-state-6395e36ea95d48ee"
    key            = "codebuild/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-sync-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
}

data "terraform_remote_state" "s3" {
  backend = "s3"
  config = {
    bucket = "terraform-sync-state-6395e36ea95d48ee"
    key    = "s3/terraform.tfstate"
    region = "us-east-1"
  }
}