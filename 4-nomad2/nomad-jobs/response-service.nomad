job "response-service" {
  datacenters = ["dc1"]

  group "response-group" {
    count = 1
    
    network {
    dns {
    	servers = ["172.17.0.1"]
     }
      mode = "bridge"
      port "http" {
        static = 5001
      }
    }

    task "response" {
      driver = "docker"

      config {
        image = "srahul3/responseservice:latest"
        ports = ["http"]
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