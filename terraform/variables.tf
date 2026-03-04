variable "region" {
  description = "Region of AWS where the VPC is hosted"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR block"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidr" {
  description = "Private subnet CIDR block"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "eks_cluster_name" {
  description = "Name of the EKS Cluster"
  type        = string
  default     = "wiz-tasky-cluster"
}

variable "my_name" {
  description = "Name to be written into wizexercise.txt"
  type        = string
  default     = "Lorenzo Sibani"
}

variable "db_password" {
  description = "Password for MongoDB authentication"
  type        = string
  sensitive   = true
  default     = "SecurePassword12453"
}

variable "cluster_version" {
  description = "My Cluster version"
  type        = string
  default     = "1.29"
}

variable "node_groups" {
  description = "EKS node group configuration variable"
  type = map(object({
    instance_types = list(string)
    capacity_type  = string
    scaling_config = object({
      desired_size = number
      max_size     = number
      min_size     = number
    })
  }))
  # ADDED DEFAULT: This stops Terraform from asking you to type that long map manually
  default = {
    main = {
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      scaling_config = {
        desired_size = 2
        max_size     = 3
        min_size     = 1
      }
    }
  }
}

variable "mongo_ami_ssm_path" {
  type        = string
  description = "SSM Parameter path for the latest Ubuntu 20.04 AMI"
  default     = "/aws/service/canonical/ubuntu/server/20.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

variable "mongo_instance_type" {
  description = "The EC2 instance size"
  type        = string
  default     = "t3.medium"
}

variable "ssh_allowed_cidr" {
  description = "CIDR block allowed to SSH into the DB"
  type        = string
  default     = "0.0.0.0/0"
}