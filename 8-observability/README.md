
# Part 8: Platform Integration: To prod and beyond 🚀 

## Overview
This part introduces Consul for service discovery, and fault tollerance for HelloService and ResponseService.

## Prerequisites
1. **Tools Installed**:
   - Terraform CLI
   - jq cli `brew install jq`
   - Packer CLI
   - Docker CLI
2. **Packer generated AMI** (Pre-baked AMI with Consul Server, Consul Client, Docker Images, DNS Configuration):
   - An AWS account with access keys configured.
3. **Docker Images**
   - Docker images compiled in this step and are available on docker-hub.

## Steps to Run

1. **Navigate to the Part 8 directory**:
   ```bash
   cd 8-observability
   ```

2. **Building AMI using Packer**
   ```bash
   packer init -var-file=variables.hcl image.pkr.hcl
   packer build -var-file=variables.hcl image.pkr.hcl
   ```

   Record the AMI id, we will need it in next step

3. **Push Docker Images to Docker Hub**
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

4. **Code Changes**
   We will be modifying the code we built for step 4 and adding some wings to it.
   Right now we don't know what goes with our application at any moment without any manual interventions. That too, very limited information.
   In this step we will be adding couple of lines of not-so-scaringly code blocks to our application responseservice as well as helloservice which will
   help it to emit some state information. This can include metrics related to requests served, tracing information containing the request path etc.,

   You may compare the code under `./HelloService/main.go` with `4-nomad/HelloService/main.go` to understand what all metrics and tracing information has been instrumented.

5. **Deloyment**
   
   **Update variables.hcl acordingly. Sepecially the `ami`**
   ```hcl
   # Packer variables (all are required)
   region                    = "us-east-1"
   dockerhub_id              = "<your-dockerhub-ID>"

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

6. Add each of the nomad jobs under `nomad-jobs/*` to the nomad server.

7. **Testing Servers**:
   - Make sure Consul UI and Nomad UI and loading
   - Make sure Nomad shows two client
   - Make sure Consul services are healthy
   - Make sure you can access prometheus UI, Grafana UI, Jaeger UI etc.,


8. **Test the Services**:

   You can directly visit the URL: http://<ip-of-nomad-client>:5000/hello on browser or follow:
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


## Key Points
- Observability enables us to monitor our application stack 24*7 with carefully crafted alerts and playbooks which will enable our app to serve customer requests with maximum availablity.
