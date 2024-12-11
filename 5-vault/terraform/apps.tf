provider "nomad" {
  address = local.nomad
}

resource "nomad_job" "hello_service" {
  count = var.deploy_apps ? 1 : 0

  jobspec = templatefile("${path.module}/nomad-jobs/hello-service.nomad", {
    consul_server = local.consul
    vault_addr = "http://${aws_instance.vault.public_ip}:8200"
    vault_token = local.vault_token
    image = "kkavish/hello_service:latest"
    dockerhub_user = var.docker_user
    dockerhub_password = var.docker_password
  })
}

resource "nomad_job" "response_service" {
  count = var.deploy_apps ? 1 : 0

  jobspec = templatefile("${path.module}/nomad-jobs/response-service.nomad", {
    consul_server = local.consul
    secret_path = "database/creds/my-role"
    image = "kkavish/response_service:latest"
    dockerhub_user = var.docker_user
    dockerhub_password = var.docker_password
  })
}

# Add EC2 instance for HelloService
resource "aws_instance" "apps" {
  count = var.deploy_apps ? 0 : 0
  ami           = var.ami
  instance_type = var.instance_type
  key_name      = aws_key_pair.minion-key-vault.key_name

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y docker.io unzip curl jq

    # Configure Consul
    nohup consul agent -dev -bind=$PRIVATE_IP -client=$PRIVATE_IP -data-dir=/tmp/consul -retry-join="${var.retry_join}" &

    sudo docker login ${var.docker_registry} -u ${var.docker_user} -p ${var.docker_password}
    sudo docker pull ${var.docker_user}/hello_service:latest
    sudo docker pull ${var.docker_user}/response_service:latest

    sudo docker run -d -e VAULT_ADDR="http://${aws_instance.vault.public_ip}:8200" -e VAULT_TOKEN=${local.vault_token} -p 5000:5000 --name hello_service ${var.docker_user}/hello_service:latest
    sudo docker run -d -e VAULT_ADDR="http://${aws_instance.vault.public_ip}:8200" -e VAULT_TOKEN=${local.vault_token} -p 5001:5001 --name response_service ${var.docker_user}/response_service:latest
  EOF

  tags = {
    "ConsulAutoJoin" = "auto-join"
  }

  vpc_security_group_ids = [aws_security_group.minion_sg.id]
  iam_instance_profile = aws_iam_instance_profile.instance_profile_vault.name
}

