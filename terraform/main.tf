terraform {
  required_version = ">= 1.5.0"

  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(var.common_tags, {
      Project     = var.project
      Owner       = var.owner
      Environment = var.environment
      ManagedBy   = "Terraform"
    })
  }

  # Subnet cluster tags are owned by the EKS module (aws_ec2_tag), not by aws_subnet
  ignore_tags {
    key_prefixes = ["kubernetes.io/cluster/"]
  }
}

module "vpc" {
  source = "./modules/vpc"

  name                 = var.vpc_name
  cidr                 = var.vpc_cidr
  azs                  = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
}

module "eks" {
  source = "./modules/eks"

  cluster_name    = var.eks_cluster_name
  cluster_version = var.eks_cluster_version

  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.private_subnet_ids
  public_subnet_ids = module.vpc.public_subnet_ids

  cluster_endpoint_public_access  = var.eks_endpoint_public_access
  cluster_endpoint_private_access = var.eks_endpoint_private_access

  node_instance_types = var.eks_node_instance_types
  node_min_size       = var.eks_node_min_size
  node_max_size       = var.eks_node_max_size
  node_desired_size   = var.eks_node_desired_size
}
