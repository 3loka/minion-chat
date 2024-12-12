output "hello_service_cli" {
  value = "curl http://${aws_instance.hello_service.public_ip}:5050/hello | jq"
}

output "response_service_cli" {
  value = "curl http://${aws_instance.response_service.public_ip}:6060/response | jq"
}

output "response_service_private_ip" {
  value = "${aws_instance.response_service.private_ip}"
}

output "env" {
    value = <<CONFIGURATION
    export HELLO_SERVICE=${aws_instance.hello_service.public_ip}
    export RESPONSE_SERVICE=${aws_instance.response_service.public_ip}
    CONFIGURATION  
}