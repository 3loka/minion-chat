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
  value = <<CONFIGURATION
    # Nomad server
    ${aws_instance.nomad_server.private_ip},

    # Nomad client
    ${aws_instance.nomad_client[0].private_ip},
    ${aws_instance.nomad_client[1].private_ip}
    CONFIGURATION
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
    ssh -i "minion-key.pem" ubuntu@${aws_instance.nomad_server.public_ip}

    # Nomad client
    ssh -i "minion-key.pem" ubuntu@${aws_instance.nomad_client[0].public_ip}
    ssh -i "minion-key.pem" ubuntu@${aws_instance.nomad_client[1].public_ip}
    CONFIGURATION
}

output "ui_urls" {
  value = <<CONFIGURATION
    Consul: http://${aws_instance.nomad_server.public_ip}:8500
    Nomad: http://${aws_instance.nomad_server.public_ip}:4646
    CONFIGURATION
}

