# 1. IAM Role for the EKS Cluster Control Plane
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.eks_cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# 2. The EKS Cluster (Hardened for 1.27 Compatibility)
resource "aws_eks_cluster" "main" {
  name     = var.eks_cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.29" 

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  vpc_config {
    subnet_ids              = aws_subnet.private[*].id
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  # THIS IS THE FINAL FIX: 
  # We must explicitly define these as empty/disabled to stop 
  # the 2026 provider from injecting Auto Mode defaults.
  compute_config {
    enabled = false
  }

  storage_config {
    block_storage {
      enabled = false
    }
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

# 3. IAM Role for Worker Nodes
resource "aws_iam_role" "eks_node_group_role" {
  name = "${var.eks_cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group_role.name
}

# 4. Managed Node Groups
resource "aws_eks_node_group" "eks-worker-node" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = each.key
  node_role_arn   = aws_iam_role.eks_node_group_role.arn
  subnet_ids      = aws_subnet.private[*].id

  instance_types = each.value.instance_types
  capacity_type  = each.value.capacity_type

  scaling_config {
    desired_size = each.value.scaling_config.desired_size
    max_size     = each.value.scaling_config.max_size
    min_size     = each.value.scaling_config.min_size
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
  ]
}

# 5. ECR Repository
resource "aws_ecr_repository" "wiz_repo" {
  name = "wiz-tasky-repository"
  # force_delete is excluded per your request
}

# 6. Docker Push (Local Exec)
resource "null_resource" "docker_push" {
  depends_on = [aws_ecr_repository.wiz_repo]

  provisioner "local-exec" {
    command = <<EOT
      aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${aws_ecr_repository.wiz_repo.repository_url}
      docker build --platform linux/amd64 -t tasky-app ../backend-app
      docker tag tasky-app:latest ${aws_ecr_repository.wiz_repo.repository_url}:latest
      docker push ${aws_ecr_repository.wiz_repo.repository_url}:latest
    EOT
  }
}