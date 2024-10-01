terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.62.0"  # This allows any version from 5.62.0 up to but not including 6.0.0
    }
  }
}

provider "aws" {
  region = "us-west-
