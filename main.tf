provider "aws" {
  region = "ca-central-1"
}

resource "aws_vpc" "exam_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Exam-VPC"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.exam_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public-Subnet"
  }
}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.exam_vpc.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "Private-Subnet"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.exam_vpc.id

  tags = {
    Name = "Exam-IGW"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.exam_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Public-Route-Table"
  }
}

resource "aws_route_table_association" "public_route" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "exam_sg" {
  name   = "Exam-Security-Group"
  vpc_id = aws_vpc.exam_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "tls_private_key" "exam_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "exam_key" {
  key_name   = "exam-key"
  public_key = tls_private_key.exam_key.public_key_openssh
}

resource "aws_instance" "exam_ec2" {
  ami                    = "ami-0bf6dbeae330f5823"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.exam_sg.id]
  key_name               = aws_key_pair.exam_key.key_name

  tags = {
    Name = "Exam-EC2"
  }
}

resource "aws_kms_key" "s3_kms" {
  description             = "S3-KMS"
  deletion_window_in_days = 7

  tags = {
    Name = "S3-KMS"
  }
}


resource "random_id" "bucket_id" {
  byte_length = 4
}

resource "aws_s3_bucket" "exam_logs" {
  bucket = "exam-logs-${random_id.bucket_id.hex}"

  tags = {
    Name = "Exam-Logs"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.exam_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_kms.arn
    }
  }
}

resource "aws_dynamodb_table" "sessions" {
  name         = "Exam-Sessions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "SessionId"

  attribute {
    name = "SessionId"
    type = "S"
  }

  tags = {
    Name = "Exam-Sessions"
  }
}