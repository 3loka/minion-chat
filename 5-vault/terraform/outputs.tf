output "vault_ui_url" {
  value = "http://${aws_instance.vault.public_ip}:8200"
}

#output "hello_service_url" {
#  value = var.deploy_apps ? "http://${aws_instance.apps[0].public_ip}:5000" : ""
#}
#
#output "response_service_url" {
#  value = var.deploy_apps ? "http://${aws_instance.apps[0].public_ip}:5001" : ""
#}


# nomad_and_consul output


output "private_ip" {
  value = {
    consul = aws_instance.nomad_server.private_ip
    nomad = [aws_instance.nomad_server.private_ip, aws_instance.nomad_client[0].private_ip, aws_instance.nomad_client[1].private_ip]
  }
}

output "instance_ids" {
  value = {
    consul = aws_instance.nomad_server.host_id
    nomad = [aws_instance.nomad_server.host_id, aws_instance.nomad_client[0].host_id, aws_instance.nomad_client[1].host_id]
  }
}

output "ssh" {
  value = <<CONFIGURATION
    # Nomad server
    ssh -i "minion-key-vault.pem" ubuntu@${aws_instance.nomad_server.public_ip}

    # Nomad client
    ssh -i "minion-vault-key.pem" ubuntu@${aws_instance.nomad_client[0].public_ip}
    ssh -i "minion-vault-key.pem" ubuntu@${aws_instance.nomad_client[1].public_ip}
    CONFIGURATION
}

output "ui_urls" {
  value = {
    consul = local.consul
    nomad = local.nomad
  }
}

output "vault_token" {
  value = local.vault_token
  sensitive = true
}
