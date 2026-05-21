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
# Get latest CentOS 7/Stream AMI (official owner)
# ---------------------------------------------------
data "aws_ami" "centos" {
  most_recent = true
  owners      = ["125523088429"] # CentOS official (AWS marketplace)

  filter {
    name   = "name"
    values = ["CentOS*7*"] # or CentOS Stream if available
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
  filename        = "${path.module}/church-key.pem"
  file_permission = "0400"
}

resource "aws_key_pair" "church_key" {
  key_name   = "church-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# ---------------------------------------------------
# Security Group (SSH + HTTP)
# ---------------------------------------------------
resource "aws_security_group" "church_sg" {
  name        = "church-sg"
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
# EC2 Instance (CentOS)
# ---------------------------------------------------
resource "aws_instance" "church" {
  ami                    = data.aws_ami.centos.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.church_key.key_name
  vpc_security_group_ids = [aws_security_group.church_sg.id]

  tags = {
    Name = "churchserver"
  }
}

# ---------------------------------------------------
# Outputs
# ---------------------------------------------------
output "server_ip" {
  value = aws_instance.church.public_ip
}

output "ssh_command" {
  value = "ssh -i church-key.pem centos@${aws_instance.church.public_ip}"
}

output "private_key_location" {
  value = "${path.module}/church-key.pem"
}