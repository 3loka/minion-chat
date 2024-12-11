job "hello-service" {
  datacenters = ["dc1"]

  group "hello-group" {
    count = 1
    
    network {
    dns {
    	servers = ["${consul_server}"]
     }
      mode = "bridge"
      port "http" {
        static = 5000
      }
    }

    task "hello" {
      driver = "docker"

      env {
        VAULT_ADDR = "${vault_addr}"
        VAULT_TOKEN = "${vault_token}"
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
        name = "hello-service"
        port = "http"

        check {
          type     = "http"
          path     = "/hello"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
