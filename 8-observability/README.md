
# Part 8: Platform Integration: To prod and beyond 🚀

This part introduces the critical practices required for taking services to production. The focus will be on understanding and implementing an observability stack, setting up alerts for proactive monitoring, and learning fault-handling strategies through real-world simulations for the services `HelloService` and `ResponseService`.

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
- **Jaeger** (port: `16686`) - Helps to explore application traces

## 🎯 Monitoring Targets
We’ll monitor:
- `hello-service` – A custom web app.
- `response-service` – Another web app, also backend for hello-service.
- **Nomad** and **Consul** metrics.
- Plus, we’ll configure **alert rules** and **webhook notifications** for real-time alerting.

## 🚀 Step-by-Step Setup

### 1. Code Changes
   We will be modifying the code we built for step 4 and adding some observability wings to it.
   Right now, we don't know what goes with our application at any moment without any manual checks. That too, with very limited information.
   In this step we will be adding couple of lines of not-so-scaringly code blocks to our application responseservice as well as helloservice which will help it to emit some state information. This can include metrics related to requests served, tracing information containing the request path etc.,

   You may compare the code under `./HelloService/main.go` with `4-nomad/HelloService/main.go` to understand what all metrics and tracing information has been instrumented.

### 2. Push Docker Images to Docker Hub
   If necessary, update the tags from the docker-compose.yml.

   Open a new terminal to build docker and set the following env

   ```bash
   # Set up Docker Hub credentials  
   export TF_VAR_dockerhub_id=<dockerhub-id>
   curl -L https://hub.docker.com/v2/orgs/$TF_VAR_dockerhub_id | jq
   # make sure you see your account information in response

   DOCKER_DEFAULT_PLATFORM=linux/amd64  docker-compose build
   DOCKER_DEFAULT_PLATFORM=linux/amd64  docker-compose push
   ```

### 3. Deploy the infrastructure changes

Since we're adding couple more services in this step, we need to expose those ports to the outside world so that we can access the services. 

For that
1. `terraform init`
2. `terraform apply -var-file=variables.hcl`

### 4. Deploy the Stack
Let’s deploy the monitoring stack on **Nomad**.

1. Open **Nomad UI**.
2. Go to **Jobs > Run Job**.
3. Paste the contents of `hello-service.nomad` `response-service.nomad` `monitoring-stack.nomad` `tracing.nomad` into the job submission form in this order.
4. Hit **Submit** for each of them!

Now, sit back and let Nomad launch the monitoring stack for you! 🔥

---

### 5. Configure Prometheus

Prometheus scrapes metrics from the following targets:
- **Consul**: `consul.service.consul:8500`
- **Nomad**: `nomad.service.consul:4646`
- **hello-service**: `hello-service.service.consul:5050`
- **response-service**: `response-service.service.consul:6060`

The Prometheus config is defined in `prometheus.yml`. To view the metrics:
- Open **Prometheus** at: `http://<nomad-server-ip>:9090`.
- Explore the available targets under **Status > Targets**.

---

### 6. Visualize Metrics in Grafana

Let’s make those metrics beautiful! 🎨

1. Open **Grafana** at: `http://<nomad-server-ip>:3000`.
2. Import pre-built dashboards:
    - Go to **Dashboards > Import**.
    - Upload the JSON files from the `grafana-dashboards` folder.
3. You’ll now see real-time metrics for **Nomad**, **Consul**, **hello-service**, and **response-service**.

---

### 7. Set Up Alerting with Alertmanager

Now let’s configure alerting rules to notify us when something goes wrong.

Alertmanager is already provisioned to handle alerts from Prometheus and send them to a webhook.

You can access **Alertmanager UI** at: `http://<nomad-server-ip>:9093`

Here’s an example alert rule:
- **Alert**: `InstanceDown`
- **Condition**: If `response-service` is down for more than 2 minutes, an alert is triggered.

When the alert is triggered, Alertmanager will send a notification to a webhook URL (`https://webhook.site/73961b6f-bb10-44d3-9268-7fd51b71bd01`). You can monitor this in real-time.

---

### 8. Simulate an Alert 🚨

Let’s trigger an alert to see how the system reacts.

1. **Stop `response-service`**:
    - In Nomad UI, stop the `response-service` job.
2. **Watch the alert**:
    - Prometheus will notice that the service is down.
    - An alert will be triggered and sent to Alertmanager.
    - Check the alert notification at the [webhook site](https://webhook.site/#!/view/73961b6f-bb10-44d3-9268-7fd51b71bd01/4e268ed7-dfba-4db3-ae06-cc9a2617413b/1).

Pretty cool, right? 😎


### 9. Tracing

In this step let's explore on enabling distributed tracing support for our application.
We can get started by deploying jeager stack which contains open-telemtry collector as well as jaeger UI which we can use to dig deeper into traces.

* Once tracing job is deployed, access the jaeger UI through `http://<nomad-client-ip>:16686`
* Access the hello service to generate some traces for both helloservice as well as responseservice.
* Play with the Jaeger UI to understand the distributed tracing between two mircroservices.
* There's a bug which you can spot using tracing on the responseservice. See if you can find it by exploring the traces and fix it :)


---

## Full End-to-End Flow

1. **Metrics Exposure**: `hello-service` and `response-service` expose metrics as well as tracing infromation.
2. **Prometheus**: Scrapes these metrics, as well as those from Nomad and Consul.
3. **Grafana**: Visualizes the metrics in real-time using beautiful dashboards.
4. **Prometheus Alerts**: Prometheus triggers an alert when conditions are met.
5. **Tracing with OpenTelemtry**: Application exposed traces can be explored here with Jaeger.
5. **Alertmanager Escalation**: Alertmanager forwards the alert to the webhook URL for further action.

---

## 💡 Keypoints

By now, you have a fully functional monitoring setup, capable of visualizing metrics and sending real-time alerts! Keep experimenting by tweaking alert rules, adding more targets, or even exploring different visualization options in Grafana.

Adding observability to our stack enables us to monitor our application stack 24*7 with carefully crafted alerts and playbooks which will enable our app to serve customer requests with maximum availablity.

Happy Monitoring! 🎉🚀

---

## Useful Resources
- [Prometheus Documentation](https://prometheus.io/docs/introduction/overview/)
- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [Alertmanager](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [Open-Telemetry](https://opentelemetry.io/docs/)
- [Jaeger](https://www.jaegertracing.io/docs/2.1/architecture/)
