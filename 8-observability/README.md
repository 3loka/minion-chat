
# Monitoring & Alerting Setup

Welcome to the workshop! 🚀 In this hands-on guide, you'll be setting up a full monitoring and alerting stack on Nomad using Prometheus, Grafana, and Alertmanager. By the end of this setup, you'll have a complete monitoring solution in place, with real-time alerting and escalations.

## 🛠 Prerequisites
Before we begin, make sure you have:
1. **Nomad** and **Consul** installed and running.
2. Access to **Nomad UI** for deploying and managing jobs.
3. **hello-service** and **response-service** deployed on nomad.

## 📦 What You'll Be Setting Up
We’ll be deploying the following components using a single Nomad job:
- **Prometheus** (port: `9090`) – Scrapes metrics and triggers alerts.
- **Grafana** (port: `3000`) – Visualizes metrics via dashboards.
- **Alertmanager** (port: `9093`) – Handles alerts and escalates them to a webhook.

## 🎯 Monitoring Targets
We’ll monitor:
- `hello-service` – A custom web app.
- `response-service` – Another web app, also backend for hello-service.
- **Nomad** and **Consul** metrics.
- Plus, we’ll configure **alert rules** and **webhook notifications** for real-time alerting.

## 🚀 Step-by-Step Setup

### 1. Deploy the Monitoring Stack
Let’s deploy the monitoring stack on **Nomad**.

1. Open **Nomad UI**.
2. Go to **Jobs > Run Job**.
3. Paste the contents of `monitoring-stack.nomad` into the job submission form.
4. Hit **Submit**!

Now, sit back and let Nomad launch the monitoring stack for you! 🔥

---

### 2. Configure Prometheus

Prometheus scrapes metrics from the following targets:
- **Consul**: `consul.service.consul:8500`
- **Nomad**: `nomad.service.consul:4646`
- **hello-service**: `hello-service.service.consul:5050`
- **response-service**: `response-service.service.consul:5055`

The Prometheus config is defined in `prometheus.yml`. To view the metrics:
- Open **Prometheus** at: `http://<nomad-server-ip>:9090`.
- Explore the available targets under **Status > Targets**.

---

### 3. Visualize Metrics in Grafana

Let’s make those metrics beautiful! 🎨

1. Open **Grafana** at: `http://<nomad-server-ip>:3000`.
2. Import pre-built dashboards:
    - Go to **Dashboards > Import**.
    - Upload the JSON files from the `grafana-dashboards` folder.
3. You’ll now see real-time metrics for **Nomad**, **Consul**, **hello-service**, and **response-service**.

---

### 4. Set Up Alerting with Alertmanager

Now let’s configure alerting rules to notify us when something goes wrong.

Alertmanager is already provisioned to handle alerts from Prometheus and send them to a webhook.

You can access **Alertmanager UI** at: `http://<nomad-server-ip>:9093`

Here’s an example alert rule:
- **Alert**: `InstanceDown`
- **Condition**: If `response-service` is down for more than 2 minutes, an alert is triggered.

When the alert is triggered, Alertmanager will send a notification to a webhook URL (`https://webhook.site/73961b6f-bb10-44d3-9268-7fd51b71bd01`). You can monitor this in real-time.

---

### 5. Simulate an Alert 🚨

Let’s trigger an alert to see how the system reacts.

1. **Stop `response-service`**:
    - In Nomad UI, stop the `response-service` job.
2. **Watch the alert**:
    - Prometheus will notice that the service is down.
    - An alert will be triggered and sent to Alertmanager.
    - Check the alert notification at the [webhook site](https://webhook.site/#!/view/73961b6f-bb10-44d3-9268-7fd51b71bd01/4e268ed7-dfba-4db3-ae06-cc9a2617413b/1).

Pretty cool, right? 😎

---

## 🎉 Full End-to-End Flow

1. **Metrics Exposure**: `hello-service` and `response-service` expose metrics.
2. **Prometheus**: Scrapes these metrics, as well as those from Nomad and Consul.
3. **Grafana**: Visualizes the metrics in real-time using beautiful dashboards.
4. **Prometheus Alerts**: Prometheus triggers an alert when conditions are met.
5. **Alertmanager Escalation**: Alertmanager forwards the alert to the webhook URL for further action.

---

## 💡 Conclusion

By now, you have a fully functional monitoring setup, capable of visualizing metrics and sending real-time alerts! Keep experimenting by tweaking alert rules, adding more targets, or even exploring different visualization options in Grafana.

Happy Monitoring! 🎉🚀

---

## Useful Resources
- [Prometheus Documentation](https://prometheus.io/docs/introduction/overview/)
- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [Alertmanager](https://prometheus.io/docs/alerting/latest/alertmanager/)
