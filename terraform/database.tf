data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's official AWS ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# --- PREVENTATIVE CONTROL: Permissions Boundary ---
resource "aws_iam_policy" "guardrail_boundary" {
  name        = "Wiz-Security-Boundary"
  description = "Preventative Control: Restricts access to sensitive logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowAll"
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
      },
      {
        Sid      = "DenyLogDeletion"
        Effect   = "Deny"
        Action   = ["logs:DeleteLogGroup", "logs:DeleteLogStream"]
        Resource = "*"
      }
    ]
  })
}

# --- IAM Role with Boundary ---
resource "aws_iam_role" "mongo_admin_role" {
  name                 = "wiz-mongo-admin-role"
  permissions_boundary = aws_iam_policy.guardrail_boundary.arn # ADDED BOUNDARY

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "admin_attach" {
  role       = aws_iam_role.mongo_admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "mongo_profile" {
  name = "wiz-mongo-instance-profile"
  role = aws_iam_role.mongo_admin_role.name
}

# --- Security Group ---
resource "aws_security_group" "mongo_sg" {
  name        = "wiz-mongodb-sg"
  vpc_id      = aws_vpc.Wiz_Exercise_vpc.id
  description = "Security group for MongoDB with public SSH access" # FIX: Added description for Checkov

  ingress {
    description = "Public SSH Access for management" # FIX: Added description for Checkov
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Mongo access from VPC"
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

# --- EC2 Instance ---
resource "aws_instance" "mongodb_vm" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.mongo_instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.mongo_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.mongo_profile.name
  associate_public_ip_address = true
  key_name                    = "MongoDBEC2-Key"
  monitoring                  = true # FIX: Enable detailed monitoring (Detective Control)
  ebs_optimized               = true # Best practice

  user_data = <<-EOF
              #!/bin/bash
              wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | sudo apt-key add -
              echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
              apt-get update
              apt-get install -y mongodb-org awscli

              systemctl start mongod
              systemctl enable mongod

              sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf
              systemctl restart mongod
              
              cat << 'SCRIPT' > /home/ubuntu/backup.sh
              #!/bin/bash
              TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
              mongodump --archive | aws s3 cp - s3://${aws_s3_bucket.backups.id}/db-backup-\$TIMESTAMP.archive
              SCRIPT
              
              chmod +x /home/ubuntu/backup.sh
              (crontab -l 2>/dev/null; echo "0 0 * * * /home/ubuntu/backup.sh") | crontab -
              EOF

  tags = {
    Name = "Wiz-Mongo-Database"
  }
}