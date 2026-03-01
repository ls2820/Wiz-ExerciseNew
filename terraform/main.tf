terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "6.34.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "wiz_infrastructure" {
  source = "./modules"

  # We must "pass" the variables from the Root into the Module
  region               = var.region
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidr   = var.public_subnet_cidr
  private_subnet_cidr  = var.private_subnet_cidr
  availability_zones   = var.availability_zones
  eks_cluster_name     = var.eks_cluster_name
  node_groups          = var.node_groups
  my_name              = var.my_name
  db_password          = var.db_password
  mongo_ami            = var.mongo_ami
  mongo_instance_type  = var.mongo_instance_type
  ssh_allowed_cidr     = var.ssh_allowed_cidr
  cluster_version      = var.cluster_version
}

