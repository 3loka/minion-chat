output "leaderboard-ip" {
  value = aws_instance.nginx_node_instance.public_ip
}
output "leaderboard-dns" {
  value = aws_instance.nginx_node_instance.public_dns
}
output "leaderboard-url" {
  value = "http://${aws_route53_record.nginx_node_record.name}"
}
