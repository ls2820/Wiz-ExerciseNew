#!/bin/bash

# --- CONFIGURATION VARIABLES ---
# Change these values as needed for your specific AWS environment
export TF_VAR_region="us-east-1"
export TF_VAR_my_name="Lorenzo Sibani"
export TF_VAR_db_password="SecurePassword123!" # Change this!
export TF_VAR_eks_cluster_name="wiz-tasky-cluster"
export TF_VAR_cluster_version="1.29"

# --- NETWORKING ---
export TF_VAR_vpc_cidr="10.0.0.0/16"
export TF_VAR_availability_zones='["us-east-1a", "us-east-1b"]'
export TF_VAR_public_subnet_cidr='["10.0.1.0/24", "10.0.2.0/24"]'
export TF_VAR_private_subnet_cidr='["10.0.3.0/24", "10.0.4.0/24"]'

# --- EKS NODE GROUPS (The Map Object) ---
export TF_VAR_node_groups='{
  "main-workers": {
    "instance_types": ["t3.medium"],
    "capacity_type": "ON_DEMAND",
    "scaling_config": {
      "desired_size": 2,
      "max_size": 3,
      "min_size": 1
    }
  }
}'

echo "🚀 Initializing Terraform..."
terraform init

echo "🔍 Running Plan..."
# We generate the plan. If this fails, the script will stop.
if terraform plan -out=tfplan; then
    echo "🏗️  Applying Infrastructure..."
    terraform apply "tfplan"
    
    echo "✅ Deployment Complete!"
    echo "---------------------------------------------------"
    
    # Check if AWS CLI exists before running
    if command -v aws &> /dev/null; then
        aws eks update-kubeconfig --region $TF_VAR_region --name $TF_VAR_eks_cluster_name
    else
        echo "⚠️  AWS CLI not found. Please install it and run:"
        echo "aws eks update-kubeconfig --region $TF_VAR_region --name $TF_VAR_eks_cluster_name"
    fi
else
    echo "❌ Plan failed. Check the error above (likely the state lock)."
    exit 1
fi