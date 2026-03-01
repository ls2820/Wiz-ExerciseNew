resource "aws_s3_bucket" "backups" {
  bucket_prefix = "wiz-tasky-backups-"
  force_destroy = true 
}

# Allow public access
resource "aws_s3_bucket_public_access_block" "public_access_settings" {
  bucket = aws_s3_bucket.backups.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Allow public Read & List permissions
resource "aws_s3_bucket_policy" "public_read_list_policy" {
  bucket = aws_s3_bucket.backups.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowPublicReadAndList"
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject", "s3:ListBucket"]
        Resource  = [
          "${aws_s3_bucket.backups.arn}",
          "${aws_s3_bucket.backups.arn}/*"
        ]
      }
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.public_access_settings]
}