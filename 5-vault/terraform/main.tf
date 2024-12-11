provider "aws" {
  region = var.region
}

locals {
  vault_token = random_password.vault_token.result
  consul =  "http://${aws_instance.nomad_server.public_ip}:8500"
  nomad =  "http://${aws_instance.nomad_server.public_ip}:4646"
}

resource "random_password" "vault_token" {
  length  = 10
  special = false
}

resource "aws_security_group" "minion_sg" {
  name   = "${var.name_prefix}-ui-ingress"

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

  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 5001
    to_port         = 5001
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

# Add EC2 instance for Vault
resource "aws_instance" "vault" {
  ami           = var.ami
  instance_type = var.instance_type
  key_name      = aws_key_pair.minion-key-vault.key_name

  user_data = <<-EOT
    #!/bin/bash
    apt-get update -y
    apt-get install -y docker.io unzip curl jq

    # Install Vault
    curl -O https://releases.hashicorp.com/vault/1.14.1/vault_1.14.1_linux_amd64.zip
    unzip vault_1.14.1_linux_amd64.zip
    mv vault /usr/local/bin/

    # Get private IP of the instance
    export PRIVATE_IP=`wget -q -O - http://169.254.169.254/latest/meta-data/local-ipv4`

    # Configure Consul
    nohup consul agent -dev -bind=$PRIVATE_IP -client=$PRIVATE_IP -data-dir=/tmp/consul -retry-join="${var.retry_join}" > /var/log/consul.log 2>&1 &

    # Create vault config for consul backend storage
    cat <<-EOF >/home/ubuntu/config.hcl
    storage "consul" {
     address = "$PRIVATE_IP:8500"
     path    = "vault/"
    }
    listener "tcp" {
     address     = "$PRIVATE_IP:8200"
     tls_disable = 1
    }

    api_addr = "http://$PRIVATE_IP:8200"
    ui = true
    disable_mlock = true
    EOF

    # Start Vault in dev mode (for demo)
    nohup vault server -dev -dev-root-token-id="${local.vault_token}" -config=/home/ubuntu/config.hcl > /var/log/vault.log 2>&1 &
  EOT

  tags = {
    "ConsulAutoJoin" = "auto-join"
  }

  vpc_security_group_ids = [aws_security_group.minion_sg.id]
  iam_instance_profile = aws_iam_instance_profile.instance_profile_vault.name
}

resource "time_sleep" "wait_30_seconds" {
  depends_on = [aws_instance.vault]

  create_duration = "30s"
}


# Add EC2 instance for Consul
resource "aws_instance" "nomad_server" {
  depends_on = [time_sleep.wait_30_seconds]
  instance_type = var.instance_type
  ami = var.ami
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
    server_count              = 1
    region                    = var.region
    cloud_env                 = "aws"
    retry_join                = var.retry_join
    vault_token = local.vault_token
  })

  vpc_security_group_ids = [aws_security_group.minion_sg.id]
}

# Update ResponseService to register with Consul
resource "aws_instance" "nomad_client" {
  depends_on = [aws_instance.nomad_server]

  count = var.response_service_count
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
    region                    = var.region
    cloud_env                 = "aws"
    retry_join                = var.retry_join
    # for registering with Consul
    consul_ip                 = aws_instance.nomad_server.private_ip
    application_port          = 5001
    application_name          = "response-service"
    application_health_ep     = "response"
    dockerhub_id              = var.dockerhub_id
  })

  vpc_security_group_ids = [aws_security_group.minion_sg.id]
}
