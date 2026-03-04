# --- 1. AMI Definition (Ubuntu 20.04 Focal Fossa) ---
# We are using the SSM Parameter to fetch the latest 20.04 image.
# This is more reliable than hardcoding IDs which can change.
data "aws_ssm_parameter" "ubuntu_focal" {
  name = "/aws/service/canonical/ubuntu/server/20.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

# --- 2. PREVENTATIVE CONTROL: Permissions Boundary ---
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

# --- 3. IAM Role with Boundary ---
resource "aws_iam_role" "mongo_admin_role" {
  name                 = "wiz-mongo-admin-role"
  permissions_boundary = aws_iam_policy.guardrail_boundary.arn

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

resource "aws_iam_role_policy" "mongo_s3_access" {
  name = "mongo-s3-backup-policy"
  role = aws_iam_role.mongo_admin_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["s3:PutObject", "s3:PutObjectAcl"]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.backups.arn}/*"
      }
    ]
  })
}

# --- 4. Security Group ---
resource "aws_security_group" "mongo_sg" {
  name        = "wiz-mongodb-sg"
  vpc_id      = aws_vpc.Wiz_Exercise_vpc.id
  description = "Security group for MongoDB with restricted access"

  ingress {
    description = "Public SSH Access for management"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr] 
  }

  ingress {
    description     = "Mongo access from EKS Nodes only"
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.main.vpc_config[0].cluster_security_group_id] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- 5. EC2 Instance ---
resource "aws_instance" "mongodb_vm" {
  ami                         = data.aws_ssm_parameter.ubuntu_focal.value
  instance_type               = var.mongo_instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.mongo_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.mongo_profile.name
  associate_public_ip_address = true
  key_name                    = aws_key_pair.mongo_key.key_name
  monitoring                  = true 
  ebs_optimized               = true

  user_data = <<-EOF
              #!/bin/bash
              # 1. Install dependencies for Ubuntu 20.04
              apt-get update
              apt-get install -y gnupg wget apt-transport-https ca-certificates awscli

              # 2. Add MongoDB 6.0 Repo (Focal uses gpg keyrings instead of apt-key)
              wget -qO- https://www.mongodb.org/static/pgp/server-6.0.asc | gpg --dearmor | tee /usr/share/keyrings/mongodb-server-6.0.gpg > /dev/null
              echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/6.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-6.0.list

              apt-get update
              apt-get install -y mongodb-org

              systemctl start mongod
              systemctl enable mongod
              sleep 15
              
              # 3. Create Admin User
              mongosh admin --eval 'db.createUser({user: "tasky_admin", pwd: "${var.db_password}", roles: [{role: "userAdminAnyDatabase", db: "admin"}, "readWriteAnyDatabase"]})'
              
              # 4. Bind to all interfaces for EKS connectivity
              sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf
              
              # 5. Enable authentication hardening
              if ! grep -q "security:" /etc/mongod.conf; then
                echo -e "security:\n  authorization: enabled" >> /etc/mongod.conf
              else
                sudo sed -i 's/^#security:/security:\n  authorization: enabled/' /etc/mongod.conf
              fi

              # 6. Create the Daily Backup Cron Job (Runs at Midnight)
              # It dumps the database and streams it directly to your public S3 bucket
              echo "0 0 * * * root mongodump --username tasky_admin --password ${var.db_password} --authenticationDatabase admin --archive | aws s3 cp - s3://${aws_s3_bucket.backups.id}/daily-dump.gz" > /etc/cron.d/mongo-backup
              chmod 644 /etc/cron.d/mongo-backup

              # 7. Run an initial backup immediately so the bucket isn't empty for the demo
              mongodump --username tasky_admin --password ${var.db_password} --authenticationDatabase admin --archive | aws s3 cp - s3://${aws_s3_bucket.backups.id}/initial-setup-test.gz

              systemctl restart mongod
              EOF

  tags = {
    Name = "Wiz-Mongo-Database"
  }
}

# --- 6. SSH Key Pair ---
resource "aws_key_pair" "mongo_key" {
  key_name   = "MongoDBEC2-Key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC6WCZlC7sIljqz4mcUyYLTuvgDWiIaKtIa5WV4ruN3e2uYMI6KCX0NAjIVmBhNGYLmBkY3a/pAiGI6oCGK7Ae+HwbNFxeuAIv5VatUgKazpVkaRWVFpKY4YkFPBKXFSwvvhkAxcJqjxXifhBtILWQviGRaLu1/xpqGkwQ4yLOS+vAHq3v1LvZbekQRBlOo02gCk2kJJOe1rTydaXFF0A+e6MPBqjZDbX2rlr/jEEx18jrRP0mhmOMKdb/YXbduUVwmOZETdw7Fd76lkx2q/v5QtyKrKJL9GKTKUo7Y0uBiaMJ29bqKYbjzWSkCRaZyRIxdZxKsLWi62UmGhbqyZlYJ" 
}