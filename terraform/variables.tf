variable "region" {
  description = "Region of AWS where the VPC is hosted"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR block"
  type        = list(string)
}

variable "private_subnet_cidr" {
  description = "Private subnet CIDR block"
  type        = list(string)
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
}

variable "eks_cluster_name" {
  description = "Name of the EKS Cluster"
  type        = string
}

variable "my_name" {
  description = "Name to be written into wizexercise.txt"
  type        = string
}

variable "db_password" {
  description = "Password for MongoDB authentication"
  type        = string
  sensitive   = true
}

variable "cluster_version" {
  description = "My Cluster version"
  type        = string
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
}

variable "mongo_ami" {
  description = "The AMI ID for the MongoDB VM"
  type        = string
  default     = "ami-0c7217cdde317cfec" # Default for us-east-1
}

variable "mongo_instance_type" {
  description = "The EC2 instance size"
  type        = string
  default     = "t3.medium"
}

variable "ssh_allowed_cidr" {
  description = "CIDR block allowed to SSH into the DB (e.g., your IP)"
  type        = string
  default     = "0.0.0.0/0" # as requirement is public access
}