provider "aws" {
  region = var.aws_region
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

# Security group for HTTP and SSH
resource "aws_security_group" "minion_chat_security_group" {
  name        = "minion-chat-sg"
  description = "Allow HTTP and SSH traffic"

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Consul
  ingress {
    from_port       = 8500
    to_port         = 8500
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  # minion
  ingress {
    from_port       = 5050
    to_port         = 5050
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  # minion
  ingress {
    from_port       = 6060
    to_port         = 6060
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  # Nomad
  ingress {
    from_port       = 4646
    to_port         = 4646
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }
  ingress {
    from_port       = 4647
    to_port         = 4647
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  # vault
  ingress {
    from_port       = 8200
    to_port         = 8200
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }
  ingress {
    from_port       = 8201
    to_port         = 8201
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  # boundary worker
  ingress {
    from_port       = 9202
    to_port         = 9202
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  # allow_all_internal_traffic
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# HelloService EC2 instance
resource "aws_instance" "boundary_worker" {
  depends_on    = [aws_instance.response_service]
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.minion-key.key_name

  user_data = templatefile("${path.module}/worker.sh", {
    server_count              = 1
    region                    = "us-east-1"
    cloud_env                 = "aws"
    boundary_cluster_id       = var.boundary_cluster_id
  })

  tags = merge(
    {
      "Name" = "minion-chat-boundary-server"
    }
  )

  vpc_security_group_ids = [aws_security_group.minion_chat_security_group.id]
}

# ResponseService EC2 instance
resource "aws_instance" "response_service" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.minion-key.key_name


  // disable public ip
  associate_public_ip_address = false

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y docker.io

    # Set the environment variable globally
    echo "export TF_VAR_dockerhub_id=${var.dockerhub_id}" >> /etc/environment
    echo "export TF_VAR_dockerhub_id=${var.dockerhub_id}" | sudo tee --append /home/ubuntu/.bashrc

    systemctl start docker
    docker run -d --name 'response_service' -p 6060:6060 ${var.dockerhub_id}/responseservice:latest
  EOF

  tags = merge(
    {
      "Name" = "minion-chat-response-service"
    }
  )

  vpc_security_group_ids = [aws_security_group.minion_chat_security_group.id]
}

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
