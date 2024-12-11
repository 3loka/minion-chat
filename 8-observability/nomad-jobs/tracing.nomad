job "jaeger" {
  datacenters = ["dc1"]

  group "jaeger-group" {
    count = 1

    network {
      dns {
    	servers = ["172.17.0.1"]
      }
      mode = "bridge"
      port "http" {
        static = 16686
      }
      port "grpc" {
        static = 4317
      }
      port "otlp" {
        static = 4318
      }
      port "config" {
        static = 5778
      }
      port "zipkin" {
        static = 9411
      }
    }

    task "jaeger" {
      driver = "docker"

      config {
        image = "jaegertracing/jaeger:2.1.0"
        ports = ["http", "grpc", "otlp", "config", "zipkin"]
      }

      resources {
        cpu    = 500
        memory = 256
      }

    }
  }
}
