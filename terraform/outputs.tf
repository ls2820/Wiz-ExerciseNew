# Access the module outputs using: module.<module_name>.<output_name>

output "STEP_1_SSH_TO_MONGODB" {
  value = "ssh -i YOUR_KEY.pem ubuntu@${module.wiz_infrastructure.mongodb_public_ip}"
}

output "STEP_2_MONGODB_INTERNAL_URI" {
  value     = "mongodb://admin:${var.db_password}@${module.wiz_infrastructure.mongodb_private_ip}:27017"
  sensitive = true
}

output "STEP_3_KUBECONFIG_COMMAND" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${module.wiz_infrastructure.cluster_name}"
}

# output "STEP_4_APP_URL" {
#  value = "http://${module.wiz_infrastructure.load_balancer_hostname}"
# }

output "STEP_5_BACKUP_S3_BUCKET" {
  value = "https://s3.console.aws.amazon.com/s3/buckets/${module.wiz_infrastructure.backup_bucket_name}"
}