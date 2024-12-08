output "vault_ui_url" {
  value = "http://${aws_instance.vault.public_ip}:8200"
}

output "hello_service_url" {
  value = var.deploy_apps ? "http://${aws_instance.apps[0].public_ip}:5000" : ""
}

output "response_service_url" {
  value = var.deploy_apps ? "http://${aws_instance.apps[0].public_ip}:5001" : ""
}
