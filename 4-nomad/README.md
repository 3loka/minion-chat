
# Part 4: Nomad Integration

## Background
Our Hello app is already running with following limitations
1. **Manual Application Management**: Application lifecycle is difficult to maintain using terraform/manually. The compute is not utilized efficiently.
2. **Lack of Resource Optimization** One AWS Instance per Service Instance is not the efficient and cost effective way to run production.
3. **Insecure Secret Management**: Secrets are hardcoded and not securely handled.

## Overview
This part introduces Nomad for Application Lifecycle Management for HelloService and ResponseService.

**Responsibility Segrigation:**
Considering the two different personas `Platform Engineer` and `DevOps`,  Infrastucture ochestration and Application orchestration is two different things and must be isolates to better management.

**Application Management(DevOps).**
e.g . When we checking the code, the CI/CD shall build the docker images and Nomad orchestrates it on existing Infrastructure.

GitHub Action integartion with Nomad
```hcl
name: Deploy Nomad Job
on: [push]
jobs:
  deploy:
    name: Nomad Deploy
    runs-on: ubuntu-latest
    steps:
      - name: Checkout the code
        uses: actions/checkout@v1

      - name: Deploy with Nomad
        uses: qazz92/nomad-deploy
        with:
          token: ${{ secrets.YOUR_NOMAD_SECRET }}
          address: ${{ secrets.YOUR_NOMAD_SERVER }}
          job: path/to/your/nomad/job/file
          config: path/to/your/levant/config/file
```

**Platform Team:**
Monitors the existing infra performance and there is need to scale up, they shall add more nodes to the Nomad cluster.

In today's activity in first step, Lets orchestrate the infra of 2 nodes and in later steps lets use Nomad to orchestrate the application separately.

```

## Prerequisites
1. **Tools Installed**:
   - Terraform CLI
   - jq CLI
   - Packer CLI
2. **Packer generated AMI** (Pre-baked AMI with Consul Server, Consul Client, Docker Images, DNS Configuration):
   - An AWS account with access keys configured.

## Steps to Run

1. **Navigate to the Part 2 directory**:
   ```bash
   cd 4-nomad
   ```

2. **Building AMI using Packer**
   ```bash
   packer init -var-file=variables.hcl image.pkr.hcl
   packer build -var-file=variables.hcl image.pkr.hcl
   ```

   Record the AMI id, we will need it in next step

4. **Docker build**
   Open a new terminal to build docker and set the following env

   ```bash

   # Set up Docker Hub credentials  
   export TF_VAR_dockerhub_id=<dockerhub-id>
   curl -L https://hub.docker.com/v2/orgs/$TF_VAR_dockerhub_id | jq
   # make sure you see your account information in resposne

   DOCKER_DEFAULT_PLATFORM=linux/amd64  docker-compose build
   DOCKER_DEFAULT_PLATFORM=linux/amd64  docker-compose push

   ```

5. **Deloyment**
   
   **Update variables.hcl acordingly. Sepecially the `ami`**
   ```hcl
   # Packer variables (all are required)
   region                    = "us-east-1"
   dockerhub_id              = "<your-dockerhub-id>"

   # Terraform variables (all are required)
   ami                       = "<your-ami-from-previous-step>"

   name_prefix               = "minion"
   response_service_count    = 2
   ```
   
   **Run following command**
   ```bash
   terraform init
   terraform apply -var-file=variables.hcl
   ```
   Response
   ```
   Outputs:

   instance_ids = <<EOT
      i-04bdda5b8fb6acb37,
      i-06b5c92a418169db2

   EOT
   private_ip = <<EOT
      # Nomad server
      172.31.25.61,

      # Nomad client
      172.31.16.189,
      172.31.29.204

   EOT
   ssh = <<EOT
      # Nomad server
      ssh -i "minion-key.pem" ubuntu@23.22.218.131

      # Nomad client
      ssh -i "minion-key.pem" ubuntu@3.94.166.246
      ssh -i "minion-key.pem" ubuntu@34.229.194.154

   EOT
   ui_urls = <<EOT
      Consul Server: http://23.22.218.131:8500
      Nomad Server: http://23.22.218.131:4646
   EOT
   ```
4. **Testing Servers**:
   - Make sure Consul UI and Nomad UI and loading
   - Make sure Nomad shows two client
   - Make sure Consul services are healthy

5. **Adding Minion phrase in Consul KV**

   SSH into first Nomad client and run below command(s)

   Verify the docker bridge ip by running below command
   ```sh
   ip -brief addr show docker0 | awk '{print $3}' | awk -F/ '{print $1}'
   ```

   :warning: Warning: If you see the result of above command other than `172.17.0.1`, then update that IP in nomad jobs.

   ```sh
   curl --request PUT --data '["Bello!", "Poopaye!", "Tulaliloo ti amo!"]' http://consul.service.consul:8500/v1/kv/minion_phrases
   ```

6. **Nomad jobs**
   Access the Nomad UI and add below to jobs. Copy the content of the job, and update env variables and paste it New Job of Nomad UI.

   4-nomad/nomad-jobs/hello-service.nomad
   4-nomad/nomad-jobs/response-service.nomad

7. **Scaling up Response Service**
   DIY: Figure out how to scale the servie to desired count 2.

8. **Test the Services**:
   - Test **HelloService**:
     ```bash
     curl http://<ip-of-nomad-client>:5000/hello | jq
     ```
   - Expected Response:
     ```json
     {
      "message": "Hello from HelloService!",
      "minion_phrases": [
         "Bello!",
         "Poopaye!",
         "Tulaliloo ti amo!"
      ],
      "response_message": "Bello from ResponseService"
     }
     ```

9. **Access Consul UI**:
   - Open the Consul UI in a browser:
     ```plaintext
     http://localhost:8500
     ```
10. **SSH to the 1st Response Service**:
   - use ssh command suggested in terraform output and connect to the instance suggested by `Hello Service response`
   - Testing DNS:
     ```bash
     curl consul.service.consul:8500
     <a href="/ui/">Moved Permanently</a>.

     curl hello-service.service.consul:5000/hello | jq
     {
      "message": "Hello from HelloService!",
      "minion_phrases": [
         "Bello!",
         "Poopaye!",
         "Tulaliloo ti amo!"
      ],
      "response_message": "Bello from ResponseService"
      }

      sudo docker pause response-service

      # The other response instance shall kick in now
      curl hello-service.service.consul:5000/hello | jq
      {
      "message": "Hello from HelloService!",
      "minion_phrases": [
         "Bello!",
         "Poopaye!",
         "Tulaliloo ti amo!"
      ],
      "response_message": "Bello from ResponseService i-0a5e388ad2762ec84!"
      }

      sudo docker unpause response-service

      # back to the first response service
      curl hello-service.service.consul:5000/hello | jq
      {
      "message": "Hello from HelloService!",
      "minion_phrases": [
         "Bello!",
         "Poopaye!",
         "Tulaliloo ti amo!"
      ],
      "response_message": "Bello from ResponseService i-05506b6e36d25223a!"
      }
     ```
11. **DIY**:
   - Read the code and identify how to add `Tank yu` to the `minion_phrases`

## Key Points
- Application management Platform like Nomad helps to easily deploy the application, scale it, provides better resource optimization, better control over scalibility.
