terraform {
  required_providers {

    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }

  }
  required_version = ">= 1.1.0"
}

provider "aws" {
  # Configure your AWS region / credentials as usual (env vars, shared config, etc.)
  region = "ap-south-1"
}