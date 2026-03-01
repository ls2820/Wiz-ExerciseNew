data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's official AWS ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# 1. Overly Permissive IAM Role (The "Security Flaw" Requirement)
resource "aws_iam_role" "mongo_admin_role" {
  name = "wiz-mongo-admin-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# Attaching AdministratorAccess makes this "overly permissive"
resource "aws_iam_role_policy_attachment" "admin_attach" {
  role       = aws_iam_role.mongo_admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "mongo_profile" {
  name = "wiz-mongo-instance-profile"
  role = aws_iam_role.mongo_admin_role.name
}

# 2. Security Group
resource "aws_security_group" "mongo_sg" {
  name        = "wiz-mongodb-sg"
  vpc_id      = aws_vpc.Wiz_Exercise_vpc.id

  # REQUIREMENT: Public SSH Access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # REQUIREMENT: Mongo access restricted to the EKS Private Subnets
  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.Wiz_Exercise_vpc.cidr_block] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. The MongoDB EC2 Instance
resource "aws_instance" "mongodb_vm" {
  ami                         = data.aws_ami.ubuntu.id # Dynamically fetches the latest available version of Ubuntu
  instance_type               = var.mongo_instance_type
  subnet_id                   = aws_subnet.public[0].id # Placed in Public Subnet
  vpc_security_group_ids      = [aws_security_group.mongo_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.mongo_profile.name
  associate_public_ip_address = true
  key_name                    = "MongoDBEC2-Key"

  # REQUIREMENT: Automated Daily Backup to S3
  user_data = <<-EOF
              #!/bin/bash
              wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | sudo apt-key add -
              echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
              apt-get update
              apt-get install -y mongodb-org awscli

              # START MONGODB
              systemctl start mongod
              systemctl enable mongod

              # FIX 3: Tell MongoDB to listen to the EKS pods (not just localhost)
              sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf
              systemctl restart mongod
              
              # Simple backup script using the IAM role permissions
              cat << 'SCRIPT' > /home/ubuntu/backup.sh
              #!/bin/bash
              TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
              mongodump --archive | aws s3 cp - s3://${aws_s3_bucket.backups.id}/db-backup-\$TIMESTAMP.archive
              SCRIPT
              
              chmod +x /home/ubuntu/backup.sh
              # Schedule cron job for midnight
              (crontab -l 2>/dev/null; echo "0 0 * * * /home/ubuntu/backup.sh") | crontab -
              EOF

  tags = {
    Name = "Wiz-Mongo-Database"
  }
}