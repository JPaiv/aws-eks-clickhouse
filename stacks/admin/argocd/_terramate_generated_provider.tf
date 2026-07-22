// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

terraform {
  required_version = ">= 1.12.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }
}
provider "aws" {
  region = "eu-north-1"
  default_tags {
    tags = {
      ManagedBy = "opentofu"
      Project   = "aws-eks-clickhouse"
    }
  }
}
