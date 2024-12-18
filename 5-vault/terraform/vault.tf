# Add EC2 instance for Postgres
resource "aws_instance" "postgres" {
  ami           = var.ami
  instance_type = var.instance_type
  key_name      = aws_key_pair.minion-key-vault.key_name

  tags = {
    "ConsulAutoJoin" = "auto-join"
  }

  user_data = <<-EOT
    #!/bin/bash
    apt-get update -y
    apt-get install -y docker.io unzip curl jq

    # Get private IP of the instance
    export PRIVATE_IP=`wget -q -O - http://169.254.169.254/latest/meta-data/local-ipv4`

    # Install postgres
    docker run --name app-postgres -p 5432:5432 -e POSTGRES_PASSWORD=${local.postgres_password} -e POSTGRES_USER=admin -d postgres

  EOT

  vpc_security_group_ids = [aws_security_group.minion_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.instance_profile_vault.name
}

resource "time_sleep" "wait_60_seconds" {
  depends_on = [aws_instance.postgres]

  create_duration = "60s"
}

# Add EC2 instance for Vault
resource "aws_instance" "vault" {
  depends_on = [time_sleep.wait_60_seconds]

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

    sleep 90s

    export VAULT_ADDR=http://$PRIVATE_IP:8200
    export VAULT_TOKEN=${local.vault_token}

    # enable vault secrets engine
    vault secrets enable database

    # configure postgres connection
    vault write database/config/app-postgres-database \
      plugin_name=postgresql-database-plugin \
      allowed_roles="app-role" \
      connection_url="postgresql://admin:{{password}}@${aws_instance.postgres.public_ip}:5432/postgres?sslmode=disable" \
      username="admin" \
      password="${local.postgres_password}"

    # Create a role for dynamic credentials
    vault write database/roles/app-role \
      db_name=app-postgres-database \
      creation_statements="CREATE USER \"{{name}}\" WITH PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
      default_ttl="1m" \
      max_ttl="1m"

  EOT

  tags = {
    "ConsulAutoJoin" = "auto-join"
  }

  vpc_security_group_ids = [aws_security_group.minion_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.instance_profile_vault.name
}
