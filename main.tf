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
# Ubuntu 22.04 LTS AMI (FREE TIER SAFE)
# ---------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Ubuntu official)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------------------------------------------------
# SSH Key
# ---------------------------------------------------
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/ubuntu-key.pem"
  file_permission = "0400"
}

resource "aws_key_pair" "ubuntu_key" {
  key_name   = "ubuntu-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# ---------------------------------------------------
# Security Group (SSH + HTTP)
# ---------------------------------------------------
resource "aws_security_group" "ubuntu_sg" {
  name        = "ubuntu-sg"
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
# EC2 Instance (FREE TIER)
# ---------------------------------------------------
resource "aws_instance" "ubuntu_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.ubuntu_key.key_name
  vpc_security_group_ids = [aws_security_group.ubuntu_sg.id]

  tags = {
    Name = "ubuntu-server"
  }
}

# ---------------------------------------------------
# OUTPUTS
# ---------------------------------------------------
output "server_ip" {
  value = aws_instance.ubuntu_server.public_ip
}

output "ssh_command" {
  value = "ssh -i ubuntu-key.pem ubuntu@${aws_instance.ubuntu_server.public_ip}"
}

output "private_key_location" {
  value = "${path.module}/ubuntu-key.pem"
}