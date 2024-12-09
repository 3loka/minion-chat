provider "aws" {
  region = var.region
}

# Security group for HTTP and SSH
resource "aws_security_group" "minion_chat_sg" {
  name        = "minion-chat-sg"
  description = "Allow HTTP and SSH traffic"

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Hello Service
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Response Service
  ingress {
    from_port   = 5001
    to_port     = 5001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Vault
  ingress {
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Consul
  ingress {
    from_port   = 8500
    to_port     = 8500
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

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's AWS account ID for Ubuntu AMIs

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# generate a new key pair
resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "minion-key" {
  key_name   = "minion-key"
  public_key = tls_private_key.pk.public_key_openssh
}

resource "local_file" "minion-key" {
  content         = tls_private_key.pk.private_key_pem
  filename        = "./minion-key.pem"
  file_permission = "0400"
}

# Add EC2 instance for Vault
resource "aws_instance" "vault" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.minion-key.key_name

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y docker.io unzip curl jq

    # Install Vault
    curl -O https://releases.hashicorp.com/vault/1.14.1/vault_1.14.1_linux_amd64.zip
    unzip vault_1.14.1_linux_amd64.zip
    mv vault /usr/local/bin/

    # Get private IP of the instance
    export PRIVATE_IP=`wget -q -O - http://169.254.169.254/latest/meta-data/local-ipv4`

    # Configure Consul for Vault storage
    nohup consul agent -dev -bind=$PRIVATE_IP -client=$PRIVATE_IP -data-dir=/tmp/consul &

    # Start Vault in dev mode (for demo)
    nohup vault server -dev -dev-listen-address=$PRIVATE_IP:8200 -dev-root-token-id="root" &
  EOF

  vpc_security_group_ids = [aws_security_group.minion_chat_sg.id]
}
