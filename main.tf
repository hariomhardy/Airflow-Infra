terraform {
  required_version = ">= 1.5.0"
  backend "s3" {
      bucket  = ""
      key     = ""
      region  = "us-east-1"
      encrypt = true
  }

  required_providers {
    aws = {
        source  = "hashicorp/aws"
        version = "~> 5.0"
    }
  }
}

provider "aws" {
    region = var.aws_region
}


module "vpc" {
    source = "./modules/vpc"

    aws_region         = var.aws_region
    vpc_cidr           = "10.0.0.0/16"
    availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
    public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
    private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]
}

module "security_groups" {
    source = "./modules/security-groups"

    vpc_id   = module.vpc.vpc_id
    vpc_cidr = module.vpc.vpc_cidr
}