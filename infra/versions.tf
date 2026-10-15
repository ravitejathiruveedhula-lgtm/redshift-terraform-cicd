terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Partial backend config. The bucket and region are passed at init time:
  #   terraform init -backend-config="bucket=<state bucket>" -backend-config="region=<region>"
  # so nothing account-specific is hard-coded in the repo.
  backend "s3" {
    key          = "redshift-lab/infra.tfstate"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = var.github_repo
    }
  }
}
