# Terraform / provider version pins.
# Course pattern (s42-s43): pin the AWS provider, keep state locally by default;
# a versioned S3 backend (s43) can be enabled in backend.tf.
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }
}

provider "aws" {
  region = var.region
}
