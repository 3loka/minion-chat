job "response-service" {
  datacenters = ["dc1"]

  group "response-group" {
    count = 1
    
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
        policies = ["response-service-job"]
      }

      template {
        data = <<EOF
{{ with secret "secret/data/database/creds/my-role" }}
DB_USERNAME="{{ .Data.data.username }}"
DB_PASSWORD="{{ .Data.data.password }}"
{{ end }}
EOF
        destination = "local/secrets.env"
        env         = true
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
