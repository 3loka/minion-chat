
# Part 3: Consul Integration

## Background
Our Hello app is already running with following limitations
1. **Microservices Discovery**: Service discovery is a big challenge
2. **Limited Availability**: Hardcoded IPs makes the setup extremly difficult to `scale-up`, `scale-down`, hence application is not HA.
3. **Limited Scalability**: Hardcoded IPs makes the setup extremly difficult to `scale-up`, `scale-down`.
4. **No Fault Tolerance**: Services may fail without recovery mechanisms.
5. **Hardcoded responses**: There is need for a persistent store for the application to generate the response dynamically without changing the code everytime.
6. **Insecure Secret Management**: Secrets are hardcoded and not securely handled.
7. **Manual Application Management**: Application lifecycle is difficult to maintain using terraform/manually. The compute is not utilized efficiently.
8. **Lack of Resource Optimization** One AWS Instance per Service Instance is not the efficient and cost effective way to run production.

## Overview
This section introduces HashiCorp Consul to enhance service discovery and fault tolerance for HelloService and ResponseService:
- **Service Discovery:** With Consul's Service Discovery feature, hardcoded IPs are no longer necessary. Services can dynamically discover each other using Consul's DNS capabilities.
- It enables seamless scaling by eliminating the need for internal load balancers for service-to-service communication.
- Services can scale up or scale down without requiring additional configuration or reconfiguration.
- **Fault tollerance:** Consul performs health checks, automatically removing unhealthy service instances from DNS records to prevent discovery of faulty instances.
- **KV:** Consul KV provides a storage easily accessible to the application.

Advance feature(Not in scope):
- **Service Mesh:** Managing Network topology and Securing the iternal communication using mTLS.

## Goal
- Eliminate the need for hardcoding IPs by detecting the Service through Consul DNS.
- Scale up the Response Service.
- Achieve fault tollerance.
- Eliminate hardcoded response.

## Steps to Run

1. **Navigate to the Part 2 directory**:
   ```bash
   cd 3-consul
   ```

2. **Building AMI using Packer**
   ```bash
   packer init -var-file=variables.hcl image.pkr.hcl
   packer build -var-file=variables.hcl image.pkr.hcl
   ```

   Record the AMI id, we will need it in next step

3. **Replace the hardcoded IPs with DNS**
   Apply below changes

   ./HelloService/main.go
   ```diff
   - resp, err := http.Get("http://localhost:6060/response") // Static URL
   + resp, err := http.Get("http://response-service.service.consul:6060/response") // Static URL
   ```

4. **Uniquely Indentifying the AWS instance**
   While we will attempt to scale up the Response Service, we need to identify which instance of Response Service serves us!

5. **Reading message dynamically from Consul KV**
   So far we are reading a hardcoded response, lets give more control to Kevin to control the response!

6. **Self registering the service to Consul Server**
   For consul to discover the instances dynamically, the instance need to register itself to Consul at startup!

7. **Push Docker Images to Docker Hub**

   ```bash
   DOCKER_DEFAULT_PLATFORM=linux/amd64  docker-compose build
   DOCKER_DEFAULT_PLATFORM=linux/amd64  docker-compose push
   ```

8. **Infra and auto deloyment**
   
   **Update variables.hcl acordingly. Sepecially the `ami`**
   ```hcl
   # Packer variables (all are required)
   region                    = "us-east-1"
   dockerhub_id              = ""

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

   Copy the env section from terraform output and execute in terminal
   ```bash
    # Sample only
    export SSH_HELLO_SERVICE="ssh -i "minion-key.pem" ubuntu@<54.152.176.160>"
    export SSH_RESPONSE_SERVICE_0="ssh -i "minion-key.pem" ubuntu@44.212.58.112"
    export SSH_RESPONSE_SERVICE_1="ssh -i "minion-key.pem" ubuntu@3.86.29.88"

    export HELLO_SERVICE=54.152.176.160
    export RESPONSE_SERVICE_0=44.212.58.112
    export RESPONSE_SERVICE_1=3.86.29.88
    ```


8. **Set the minion phrase in Consul KV**
   
   To add minion phrase in Cosnul KV
   ```sh
   curl --request PUT --data '["Bello!", "Poopaye!", "Tulaliloo ti amo!"]' http://$HELLO_SERVICE:8500/v1/kv/minion_phrases
   ```

   Expectation
   ```
   true
   ```

10. **Access Consul UI**:
   - Open the Consul UI in a browser:
     ```plaintext
     URL indicated by `consul_ui_url` from terraform output
     ```
   
     Verify the 2 instances of `Response Service` is listed and healthy.

10. **Test the Services**:
   - Test **HelloService**:
     ```bash
     curl http://$HELLO_SERVICE:5050/hello | jq
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
      "response_message": "Bello from ResponseService i-05506b6e36d25223a!"
     }
     ```

11. **SSH to the 1st Response Service**:
      Open a new setminal and set the env from terraform

      SSH into the Response Service machine which responded to the request.
      ```bash
      ssh -i "minion-key.pem" ubuntu@$RESPONSE_SERVICE_0
      ```

      Testing DNS: Run this command
      ```bash
      curl consul.service.consul:8500
      ```

      Expected output
      ```
      <a href="/ui/">Moved Permanently</a>.
      ```

      Testing DNS: Run this command
      ```bash
      curl response-service.service.consul:6060/response | jq
      ```

      Expected output
      ```json
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

      Run
      ```bash
      sudo docker pause response-service
      ```


      **Test `Hello Service` again in previous terminal**
      ```bash
      # The other response instance shall kick in now
      curl http://$HELLO_SERVICE:5050/hello | jq
      ```

      Expectation: The other instance of Response Service starts serving the requests. 
      ```json
      {
      "message": "Hello from HelloService!",
      "minion_phrases": [
         "Bello!",
         "Poopaye!",
         "Tulaliloo ti amo!"
      ],
      "response_message": "Bello from ResponseService i-0a5e388ad2762ec84!"
      }
      ```

      Restore the service
      ```bash
      sudo docker unpause response-service
      ```
      
12. **DIY**:
   - Read the code and identify how to add `Tank yu` to the `minion_phrases`

## Key Points
- Dynamic service discovery: HelloService resolves ResponseService using Consul.
- Centralized configuration via KV store.
- Fault tollerant via consul circuit breaker
