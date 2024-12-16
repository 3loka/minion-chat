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
        image = "abbycke/responseservice:0.0.2"
        ports = ["http"]
      }

      service {
        name = "response-service"
        port = "http"

        check {
          type     = "http"
          path     = "/health"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}