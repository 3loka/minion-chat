job "monitoring-stack" {
    datacenters = ["dc1"]

    group "monitoring" {
        count = 1

        network {
            dns {
                servers = ["172.17.0.1"]
            }
            mode = "bridge"
            port "prometheus" {
                static = 9090
            }
            port "grafana" {
                static = 3000
            }
            port "alertmanager" {
                static = 9093
            }
        }

        task "prometheus" {
            driver = "docker"

            config {
                image = "prom/prometheus:latest"
                ports = ["prometheus"]
                volumes = [
                    "local/prometheus.yml:/etc/prometheus/prometheus.yml",
                ]
            }

            service {
              name = "prometheus"
              port = "prometheus"

              check {
                type     = "http"
                path     = "/"
                interval = "10s"
                timeout  = "2s"
              }
            }

            resources {
                cpu    = 500
                memory = 512
            }

            template {
                data = <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'consul'
    static_configs:
      - targets: ['consul.service.consul:8500']

  - job_name: 'nomad'
    static_configs:
      - targets: ['nomad.service.consul:4646']

  - job_name: 'helloservice'
    static_configs:
      - targets: ['hello-service.service.consul:5000']

  - job_name: 'responseservice'
    static_configs:
      - targets: ['response-service.service.consul:5001']

  - job_name: 'prometheus'
    static_configs:
      - targets: ['prometheus.service.consul:9090']

  - job_name: 'grafana'
    static_configs:
      - targets: ['grafana.service.consul:3000']

  - job_name: 'alertmanager'
    static_configs:
      - targets: ['alertmanager.service.consul:9093']
EOF
                destination = "local/prometheus.yml"
            }
        }

        task "grafana" {
            driver = "docker"

            config {
                image = "grafana/grafana:latest"
                ports = ["grafana"]
                volumes = [
                    "local/grafana/provisioning/datasources/prometheus.yml:/etc/grafana/provisioning/datasources/prometheus.yml",
                ]
            }
            
            service {
              name = "grafana"
              port = "grafana"

              check {
                type     = "http"
                path     = "/"
                interval = "10s"
                timeout  = "2s"
              }
            }

            resources {
                cpu    = 500
                memory = 512
            }

            template {
                data = <<EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus.service.consul:9090
    isDefault: true
EOF
                    destination = "local/grafana/provisioning/datasources/prometheus.yml"
                }
        }

        task "alertmanager" {
            driver = "docker"

            config {
                image = "prom/alertmanager:latest"
                ports = ["alertmanager"]
                volumes = [
                    "local/alertmanager.yml:/etc/alertmanager/alertmanager.yml",
                ]
            }

            service {
              name = "alertmanager"
              port = "alertmanager"

              check {
                type     = "http"
                path     = "/"
                interval = "10s"
                timeout  = "2s"
              }
            }

            resources {
                cpu    = 500
                memory = 512
            }

            template {
                data = <<EOF
global:
  resolve_timeout: 5m
  smtp_from: "alertmanager@example.org"

route:
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 1h
  receiver: webhook

receivers:
- name: webhook
  webhook_configs:
  - url: 'https://webhook.site/73961b6f-bb10-44d3-9268-7fd51b71bd01'
    send_resolved: true

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname']
EOF
                destination = "local/alertmanager.yml"
            }
        }
    }
}
