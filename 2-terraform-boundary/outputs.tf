output "response_service_private_ip" {
  value = "${aws_instance.response_service.private_ip}"
}

output "ssh_boundary_worker" {
  value = <<CONFIGURATION
    ssh -i "minion-key.pem" ubuntu@${aws_instance.boundary_worker.public_ip}
    CONFIGURATION
}