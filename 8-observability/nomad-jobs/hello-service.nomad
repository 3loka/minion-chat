job "hello-service" {
  datacenters = ["dc1"]

  group "hello-group" {
    count = 1
    
    network {
    dns {
    	servers = ["172.17.0.1"]
     }
      mode = "bridge"
      port "http" {
        static = 5000
      }
    }

    task "hello" {
      driver = "docker"

      config {
        image = "abbycke/helloservice:0.0.2"
        ports = ["http"]
      }

      service {
        name = "hello-service"
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