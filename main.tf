terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.0.1"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

### VPC ###

resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  # Enable DNS hostnames 
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-sessionmanager-jumpserver"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "ig-ec2-sessionmanager-jumpserver"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "rt-private-sessionmanager-jumpserver"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.91.0/24"
  availability_zone = var.ec2_az

  tags = {
    Name = "subnet-private-sessionmanager-jumpserver"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# This will clean up all the default entries according to CKV2_AWS_12
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id
}

### SECURITY GROUP ###

resource "aws_security_group" "ssm" {
  name        = "ec2-sessionmanager-jumpserver"
  description = "Controls access for EC2 via Session Manager"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-sessionmanager-jumpserver"
  }
}


### JUMP SERVER ###

resource "aws_network_interface" "jumpserver" {
  subnet_id       = aws_subnet.private.id
  security_groups = [aws_security_group.ssm.id]

  tags = {
    Name = "ni-sessionmanager-jumpserver"
  }
}

resource "aws_iam_instance_profile" "jumpserver" {
  name = "sessionmanager-jumpserver"
  role = aws_iam_role.jumpserver.id
}

resource "aws_instance" "jumpserver" {
  ami           = var.ami
  instance_type = var.instance_type

  availability_zone    = var.ec2_az
  iam_instance_profile = aws_iam_instance_profile.jumpserver.id
  user_data            = file("${path.module}/userdata.sh")

  network_interface {
    network_interface_id = aws_network_interface.jumpserver.id
    device_index         = 0
  }

  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Name = "ec2-sessionmanager-jumpserver"
  }
}

### IAM Role ###

resource "aws_iam_role" "jumpserver" {
  name = "sessionmanager-jumpserver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

data "aws_iam_policy" "AmazonSSMManagedInstanceCore" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ssm-managed-instance-core" {
  role       = aws_iam_role.jumpserver.name
  policy_arn = data.aws_iam_policy.AmazonSSMManagedInstanceCore.arn
}
