locals {
  vault_token       = random_password.vault_token.result
  postgres_password = random_password.postgres_password.result
  consul            = "http://${aws_instance.nomad_server.public_ip}:8500"
  nomad             = "http://${aws_instance.nomad_server.public_ip}:4646"
}

resource "random_password" "vault_token" {
  length  = 10
  special = false
}

resource "random_password" "postgres_password" {
  length  = 10
  special = false
}

resource "aws_security_group" "minion_sg" {
  name = "${var.name_prefix}-ui-ingress"

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
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

  # minion
  ingress {
    from_port   = 5050
    to_port     = 5050
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # minion
  ingress {
    from_port   = 6060
    to_port     = 6060
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Nomad
  ingress {
    from_port   = 4646
    to_port     = 4646
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 4647
    to_port     = 4647
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # vault
  ingress {
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8201
    to_port     = 8201
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5001
    to_port     = 5001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # postgres
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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

resource "aws_iam_instance_profile" "instance_profile_vault" {
  name_prefix = var.name_prefix
  role        = aws_iam_role.instance_role_vault.name
}

resource "aws_iam_role" "instance_role_vault" {
  name_prefix        = var.name_prefix
  assume_role_policy = data.aws_iam_policy_document.instance_role_vault.json
}

data "aws_iam_policy_document" "instance_role_vault" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "auto_discover_cluster_vault" {
  name   = "${var.name_prefix}-auto-discover-cluster"
  role   = aws_iam_role.instance_role_vault.id
  policy = data.aws_iam_policy_document.auto_discover_cluster_vault.json
}

data "aws_iam_policy_document" "auto_discover_cluster_vault" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
      "autoscaling:DescribeAutoScalingGroups",
    ]

    resources = ["*"]
  }
}

# generate a new key pair
resource "tls_private_key" "pk_vault" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "minion-key-vault" {
  key_name   = "minion-key-vault"
  public_key = tls_private_key.pk_vault.public_key_openssh
}

resource "local_file" "minion-vault-key" {
  content         = tls_private_key.pk_vault.private_key_pem
  filename        = "./minion-vault-key.pem"
  file_permission = "0400"
}

resource "time_sleep" "wait_90_seconds" {
  depends_on = [aws_instance.vault]

  create_duration = "90s"
}


# Add EC2 instance for Consul
resource "aws_instance" "nomad_server" {
  depends_on    = [time_sleep.wait_90_seconds]
  instance_type = var.instance_type
  ami           = var.ami
  key_name      = aws_key_pair.minion-key-vault.key_name

  # instance tags
  # ConsulAutoJoin is necessary for nodes to automatically join the cluster
  tags = merge(
    {
      "Name" = "${var.name_prefix}-consul-service-1"
    },
    {
      "ConsulAutoJoin" = "auto-join"
    },
    {
      "NomadType" = "client"
    }
  )

  iam_instance_profile = aws_iam_instance_profile.instance_profile_vault.name

  # Enables access to the metadata endpoint (http://169.254.169.254).
  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }

  user_data = templatefile("${path.module}/shared/data-scripts/user-data-server.sh", {
    server_count = 1
    region       = var.region
    cloud_env    = "aws"
    retry_join   = var.retry_join
    vault_token  = local.vault_token
  })

  vpc_security_group_ids = [aws_security_group.minion_sg.id]
}

# Update ResponseService to register with Consul
resource "aws_instance" "nomad_client" {
  depends_on = [aws_instance.nomad_server]

  count         = var.response_service_count
  ami           = var.ami
  instance_type = var.instance_type
  key_name      = aws_key_pair.minion-key-vault.key_name

  # instance tags
  # ConsulAutoJoin is necessary for nodes to automatically join the cluster
  tags = merge(
    {
      "Name" = "${var.name_prefix}-nomad-client-${count.index}"
    },
    {
      "ConsulAutoJoin" = "auto-join"
    },
    {
      "NomadType" = "client"
    }
  )

  iam_instance_profile = aws_iam_instance_profile.instance_profile_vault.name

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }

  # initialises the instance with the runtime configuration
  user_data = templatefile("${path.module}/shared/data-scripts/user-data-client.sh", {
    region     = var.region
    cloud_env  = "aws"
    retry_join = var.retry_join
    # for registering with Consul
    consul_ip             = aws_instance.nomad_server.private_ip
    application_port      = 5001
    application_name      = "response-service"
    application_health_ep = "response"
    dockerhub_id          = var.docker_user
  })

  vpc_security_group_ids = [aws_security_group.minion_sg.id]
}
