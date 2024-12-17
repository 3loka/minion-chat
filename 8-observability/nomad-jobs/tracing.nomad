job "jaeger" {
  datacenters = ["dc1"]

  group "jaeger-group" {
    count = 1

    network {
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

      # Service for the Jaeger UI
      service {
        name = "jaeger-ui"
        port = "http"

        tags = ["tracing", "jaeger", "ui"]

        check {
          name     = "Jaeger UI health check"
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }
      }

      # Service for gRPC
      service {
        name = "jaeger-grpc"
        port = "grpc"

        tags = ["tracing", "jaeger", "grpc"]

        check {
          name     = "Jaeger gRPC health check"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }

      # Service for OTLP
      service {
        name = "jaeger-otlp"
        port = "otlp"

        tags = ["tracing", "jaeger", "otlp"]

        check {
          name     = "Jaeger OTLP health check"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }

      # Service for Config Endpoint
      service {
        name = "jaeger-config"
        port = "config"

        tags = ["tracing", "jaeger", "config"]

        check {
          name     = "Jaeger Config health check"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }

      # Service for Zipkin
      service {
        name = "jaeger-zipkin"
        port = "zipkin"

        tags = ["tracing", "jaeger", "zipkin"]

        check {
          name     = "Jaeger Zipkin health check"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
