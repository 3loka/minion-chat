provider "aws" {
  region = var.region
}

#1.  Add a new EC2 instance for Consul.
#2.  Modify HelloService and ResponseService to include Consul configuration.

resource "aws_security_group" "consul_ui_ingress" {
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

  # Monitoring stack
  ingress {
    from_port       = 9090
    to_port         = 9090
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 9093
    to_port         = 9093
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  # Fabio
  ingress {
    from_port   = 9999
    to_port     = 9999
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9998
    to_port     = 9998
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 16686
    to_port     = 16686
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 4317
    to_port     = 4317
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 4318
    to_port     = 4318
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5778
    to_port     = 5778
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9411
    to_port     = 9411
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  # minion
  ingress {
    from_port   = 5050
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

# Add EC2 instance for Consul
resource "aws_instance" "nomad_server" {
  instance_type = var.instance_type
  ami           = var.ami
  key_name      = aws_key_pair.minion-key.key_name

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

  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

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
  })

  vpc_security_group_ids = [aws_security_group.consul_ui_ingress.id]
}

# Update ResponseService to register with Consul
resource "aws_instance" "nomad_client" {
  depends_on    = [aws_instance.nomad_server]
  count         = var.response_service_count
  ami           = var.ami
  instance_type = var.instance_type
  key_name      = aws_key_pair.minion-key.key_name

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

  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

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
    application_port      = 6060
    application_name      = "response-service"
    application_health_ep = "response"
    dockerhub_id          = var.dockerhub_id
  })

  vpc_security_group_ids = [aws_security_group.consul_ui_ingress.id]
}



resource "aws_iam_instance_profile" "instance_profile" {
  name_prefix = var.name_prefix
  role        = aws_iam_role.instance_role.name
}

resource "aws_iam_role" "instance_role" {
  name_prefix        = var.name_prefix
  assume_role_policy = data.aws_iam_policy_document.instance_role.json
}

data "aws_iam_policy_document" "instance_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "auto_discover_cluster" {
  name   = "${var.name_prefix}-auto-discover-cluster"
  role   = aws_iam_role.instance_role.id
  policy = data.aws_iam_policy_document.auto_discover_cluster.json
}

data "aws_iam_policy_document" "auto_discover_cluster" {
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
resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "minion-key" {
  key_name   = "minion-key-observability"
  public_key = tls_private_key.pk.public_key_openssh
}

resource "local_file" "minion-key" {
  content         = tls_private_key.pk.private_key_pem
  filename        = "./minion-key.pem"
  file_permission = "0400"
}