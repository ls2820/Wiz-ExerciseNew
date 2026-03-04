resource "aws_guardduty_detector" "detective_control" {
  enable = true
}

# Preventative Control: S3 Gateway Endpoint
# This ensures S3 traffic stays within the AWS private network
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.Wiz_Exercise_vpc.id
  service_name = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"

  # Automatically associate with your route tables
  route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private[*].id
  )

  tags = {
    Name = "Wiz-Prevent-Exfiltration-Endpoint"
  }
}