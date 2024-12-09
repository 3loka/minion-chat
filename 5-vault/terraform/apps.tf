
# Add EC2 instance for HelloService
resource "aws_instance" "apps" {
  count = var.deploy_apps ? 1 : 0
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.minion-key.key_name

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y docker.io unzip curl jq

    sudo docker login ${var.docker_registry} -u ${var.docker_user} -p ${var.docker_password}
    sudo docker pull ${var.docker_user}/hello_service:latest
    sudo docker pull ${var.docker_user}/response_service:latest

    sudo docker run -d -e VAULT_ADDR="http://${aws_instance.vault.public_ip}:8200" -e VAULT_TOKEN="root" -p 5000:5000 --name hello_service ${var.docker_user}/hello_service:latest
    sudo docker run -d -e VAULT_ADDR="http://${aws_instance.vault.public_ip}:8200" -e VAULT_TOKEN="root" -p 5001:5001 --name response_service ${var.docker_user}/response_service:latest
  EOF

  vpc_security_group_ids = [aws_security_group.minion_chat_sg.id]
}
