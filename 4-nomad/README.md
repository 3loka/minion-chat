
# Part 4: Nomad Integration

## Overview
This part introduces Consul for service discovery, and fault tollerance for HelloService and ResponseService.

## Prerequisites
1. **Tools Installed**:
   - Terraform CLI
   - jq cli `brew install jq`
   - Packer cli
2. **Packer generated AMI** (Pre-baked AMI with Consul Server, Consul Client, Docker Images, DNS Configuration):
   - An AWS account with access keys configured.
3. **Docker Images**
   - Docker images compiled in last activity and available on docker-hub

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

3. **Deloyment**
   
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

5. **Adding Minion phrase ion Consul KV**

   SSH into first Nomad client and run below command(s)

   Verify the docker bridge ip by running below command
   ```sh
   ip -brief addr show docker0 | awk '{print $3}' | awk -F/ '{print $1}'
   ```

   :warning: Warning: If you see the result of above command other than `172.17.0.1`, then update that IP in nomad jobs.

   ```sh
   curl --request PUT --data '["Bello!", "Poopaye!", "Tulaliloo ti amo!"]' http://consul.service.consul:8500/v1/kv/minion_phrases
   ```


4. **Test the Services**:
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

5. **Access Consul UI**:
   - Open the Consul UI in a browser:
     ```plaintext
     http://localhost:8500
     ```
6. **SSH to the 1st Response Service**:
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
7. **DIY**:
   - Read the code and identify how to add `Tank yu` to the `minion_phrases`

## Key Points
- Dynamic service discovery: HelloService resolves ResponseService using Consul.
- Centralized configuration via KV store.
- Application lifecycle maangement and effective utilization of resources
- Fault tollerant
