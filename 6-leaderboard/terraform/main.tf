provider "aws" {
  region = var.aws_region # Change to your region
}

# Security Group
resource "aws_security_group" "nginx_node_sg" {
  name        = "nginx-node-sg"
  description = "Allow HTTP, HTTPS, and Node.js backend traffic"

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow Node.js backend traffic"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
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

# EC2 Instance
resource "aws_instance" "nginx_node_instance" {
  ami           =  data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.leaderboard-key.key_name
  security_groups = [aws_security_group.nginx_node_sg.name]

  user_data = file("userdata.sh")

  provisioner "remote-exec" {
    inline = [
      # Wait for Node.js and Nginx to be installed
      "while ! command -v npm; do echo 'Waiting for Node.js...'; sleep 10; done",
      "while ! command -v pm2; do echo 'Waiting for PM2...'; sleep 10; done",
      "echo 'Node.js and PM2 are ready!'"
    ]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(abspath(local_file.leaderboard-key.filename))
      host        = self.public_ip
    }
  }

  # Create /var/www/html before uploading files
  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /var/www/html",
      "sudo chown ubuntu:ubuntu /var/www/html"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(abspath(local_file.leaderboard-key.filename))
      host        = self.public_ip
    }
  }

  provisioner "file" {
    source      = "../frontend/index.html"
    destination = "/var/www/html/index.html"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(abspath(local_file.leaderboard-key.filename))
      host        = self.public_ip
    }
  }

  provisioner "file" {
    source      = "../backend/index.js"
    destination = "/home/ubuntu/index.js"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(abspath(local_file.leaderboard-key.filename))
      host        = self.public_ip
    }
  }

  provisioner "file" {
    source      = "../backend/package.json"
    destination = "/home/ubuntu/package.json"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(abspath(local_file.leaderboard-key.filename))
      host        = self.public_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "cd /home/ubuntu",
      "npm install",
      "pm2 start index.js --name node-app",  # Start your app with pm2
      "pm2 save",  # Save the process list for auto-restart
      "pm2 startup | bash"  # Generate and configure a systemd service for pm2
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(abspath(local_file.leaderboard-key.filename))
      host        = self.public_ip
    }
  }


  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(abspath(local_file.leaderboard-key.filename))
    host        = self.public_ip
  }

  tags = {
    Name = "Nginx-Node-Instance"
  }
}

# Route 53 Record
resource "aws_route53_record" "nginx_node_record" {
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = 300
  records = [aws_instance.nginx_node_instance.public_ip]
}

# generate a new key pair
resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "leaderboard-key" {
  key_name   = "leaderboard-key"
  public_key = tls_private_key.pk.public_key_openssh
}

resource "local_file" "leaderboard-key" {
  content         = tls_private_key.pk.private_key_pem
  filename        = "./leaderboard-key.pem"
  file_permission = "0400"
}