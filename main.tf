terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.61.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

# ---------------------------------------------------
# AWS Provider
# ---------------------------------------------------
provider "aws" {
  region = "us-east-1"
}

# ---------------------------------------------------
# Amazon Linux 2 AMI (FREE TIER SAFE)
# ---------------------------------------------------
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------------------------------------------------
# SSH KEY
# ---------------------------------------------------
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/amazon-key.pem"
  file_permission = "0400"
}

resource "aws_key_pair" "amazon_key" {
  key_name   = "amazon-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# ---------------------------------------------------
# SECURITY GROUP
# ---------------------------------------------------
resource "aws_security_group" "amazon_sg" {
  name        = "amazon-sg"
  description = "Allow SSH and HTTP"

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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------------------------------------
# EC2 INSTANCE (FREE TIER)
# ---------------------------------------------------
resource "aws_instance" "amazon_server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.amazon_key.key_name
  vpc_security_group_ids = [aws_security_group.amazon_sg.id]

  tags = {
    Name = "amazon-linux-server"
  }
}

# ---------------------------------------------------
# OUTPUTS
# ---------------------------------------------------
output "server_ip" {
  value = aws_instance.amazon_server.public_ip
}

output "ssh_command" {
  value = "ssh -i amazon-key.pem ec2-user@${aws_instance.amazon_server.public_ip}"
}

output "private_key_location" {
  value = "${path.module}/amazon-key.pem"
}