job "response-service" {
  datacenters = ["dc1"]

  group "response-group" {
    count = 2
    
    network {
    dns {
    	servers = ["${consul_server}"]
     }
      mode = "bridge"
      port "http" {
        static = 5001
      }
    }

    task "response" {
      driver = "docker"

      vault {
        policies = ["${vault_policy}"]
      }

      template {
        data = <<EOF
{{ with secret "database/creds/app-role" }}
VAULT_APP_SECRET_DB_USERNAME="{{ .Data.username }}"
VAULT_APP_SECRET_DB_PASSWORD="{{ .Data.password }}"
{{ end }}
EOF
        env         = true

        # create a file with all the secrets above, this is for apps which require a config file instead of reading from ENV.
        destination = "secrets/db_config.json"
      }

      config {
        image = "${image}"
        ports = ["http"]
        auth {
          username = "${dockerhub_user}"
          password = "${dockerhub_password}"
        }
      }

      service {
        name = "response-service"
        port = "http"

        check {
          type     = "http"
          path     = "/response"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
