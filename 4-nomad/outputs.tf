#Add Consul UI URL
# output "hello_service_url" {
#   value = " curl  http://${aws_instance.hello_service.public_ip}:5000/hello | jq"
# }

# output "response_service_url" {
#     value = <<CONFIGURATION
#     curl http://${aws_instance.response_service[0].public_ip}:5001/response | jq
#     curl http://${aws_instance.response_service[1].public_ip}:5001/response | jq
#     CONFIGURATION
# }

output "private_ip" {
    value = {
      nomad_server = aws_instance.noamd_server.private_ip
      consul_server = aws_instance.noamd_server.private_ip
      nomad_clients = [
        aws_instance.nomad_client[0].private_ip,
        aws_instance.nomad_client[1].private_ip
      ]
      }
}

output "instance_ids" {
    value = <<CONFIGURATION
    ${aws_instance.nomad_client[0].id},
    ${aws_instance.nomad_client[1].id}
    CONFIGURATION
}

output "ssh" {
    value = <<CONFIGURATION
    # Nomad server
    ssh -i "minion-key.pem" ubuntu@${aws_instance.noamd_server.public_ip}

    # Nomad client
    ssh -i "minion-key.pem" ubuntu@${aws_instance.nomad_client[0].public_ip}
    ssh -i "minion-key.pem" ubuntu@${aws_instance.nomad_client[1].public_ip}
    CONFIGURATION
}

output "ui_urls" {
  value = {
    consul =  "http://${aws_instance.noamd_server.public_ip}:8500"
    nomad =  "http://${aws_instance.noamd_server.public_ip}:4646"
  }
}

output "security_group" {
  value = aws_security_group.consul_ui_ingress.id
}

output "tls_key" {
  value = tls_private_key.pk.private_key_pem
}

output "aws_key_pair_name" {
  value = aws_key_pair.minion-key.key_name
}

output "retry_join" {
  value = var.retry_join
}

#output "env" {
#    value = <<CONFIGURATION
#    export HELLO_SERVICE=${aws_instance.hello_service.public_ip}
#    export RESPONSE_SERVICE_0=${aws_instance.response_service[0].public_ip}
#    export RESPONSE_SERVICE_1=${aws_instance.response_service[1].public_ip}
#    CONFIGURATION
#}
#
