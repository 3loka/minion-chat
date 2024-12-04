data_dir  = "/opt/nomad/data"
bind_addr = "0.0.0.0"

# Enable the server
server {
  enabled          = true
  bootstrap_expect = 1
}

consul {
  address = "127.0.0.1:8500"
}

acl {
  enabled = false
}

vault {
  enabled          = true
  address          = "http://127.0.0.1:8200"
  task_token_ttl   = "1h"
  create_from_role = "default"
  token            = "VAULT_TOKEN"
}

