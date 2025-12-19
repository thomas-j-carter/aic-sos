terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "cell" {
  source = "../../modules/cell"

  region    = "us-east-1"
  cell_name = "mvp-us-east-1"
  vpc_cidr  = "10.10.0.0/16"

  public_subnet_cidrs  = ["10.10.0.0/24", "10.10.1.0/24"]
  private_subnet_cidrs = ["10.10.10.0/24", "10.10.11.0/24"]

  # Images (placeholder)
  api_image               = "000000000000.dkr.ecr.us-east-1.amazonaws.com/api:dev"
  orchestrator_image      = "000000000000.dkr.ecr.us-east-1.amazonaws.com/orchestrator:dev"
  connector_gateway_image = "000000000000.dkr.ecr.us-east-1.amazonaws.com/connector-gateway:dev"
  approval_image          = "000000000000.dkr.ecr.us-east-1.amazonaws.com/approval:dev"
}
