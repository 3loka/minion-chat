data_dir = "/opt/consul/data"
bind_addr = "0.0.0.0"
client_addr = "0.0.0.0"
advertise_addr = "IP_ADDRESS"

bootstrap_expect = 1

acl {
    enabled = false
}

log_level = "INFO"

server = true
ui = true

retry_join = ["RETRY_JOIN"]

service {
    name = "minion-consul"
}

ports {
  grpc = 8502
}