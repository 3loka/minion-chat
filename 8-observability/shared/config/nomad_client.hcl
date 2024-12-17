data_dir  = "/opt/nomad/data"
bind_addr = "0.0.0.0"
datacenter = "dc1"

# Enable the client
client {
  enabled = true
  options {
    "driver.raw_exec.enable"    = "0"
    "docker.privileged.enabled" = "true"
  }
  servers = ["CONSUL_SERVER_IP"]
  cni_path = "opt/cni/bin"
  cni_config_dir = "opt/cni/config"
}

# Enable metrics collection
telemetry {
  collection_interval = "1s"
  disable_hostname = true
  prometheus_metrics = true
  publish_allocation_metrics = true
  publish_node_metrics = true
}

acl {
  enabled = false
}

consul {
  address = "127.0.0.1:8500"
}

vault {
  enabled = true
  address = "http://active.vault.service.consul:8200"
}
