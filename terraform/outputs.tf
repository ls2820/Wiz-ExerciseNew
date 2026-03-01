# --- Networking Outputs ---
output "vpc_id" {
  value = aws_vpc.Wiz_Exercise_vpc.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

# --- Database & Storage Outputs ---
output "mongodb_public_ip" {
  value       = aws_instance.mongodb_vm.public_ip
  description = "Public IP of the MongoDB VM for SSH access"
}

output "mongodb_private_ip" {
  value       = aws_instance.mongodb_vm.private_ip
  description = "Internal IP used by the Go App to connect to Mongo"
}

output "backup_bucket_name" {
  value = aws_s3_bucket.backups.id
}

# --- EKS Cluster Outputs ---
output "cluster_name" {
  value = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "cluster_ca_certificate" {
  value = aws_eks_cluster.main.certificate_authority[0].data
}

# --- Application Outputs ---
/* output "load_balancer_hostname" {
  value       = kubernetes_ingress_v1.tasky_ingress.status[0].load_balancer[0].ingress[0].hostname
  description = "The public URL of your Tasky Go Application"
}
*/