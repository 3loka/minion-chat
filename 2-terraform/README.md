
# Steps to Run Part 1 (Basic Setup)

## Overview
In **Part 1**, we deploy two simple microservices, HelloService and ResponseService, to demonstrate basic inter-service communication. 
HelloService acts as the primary entry point, handling requests to its /hello endpoint. 
It fetches a response from ResponseService at its /response endpoint and combines the messages into a single JSON output.
HelloService returns a friendly message "Hello from HelloService!" alongside the "Bello from ResponseService!" response received from ResponseService.
The two services communicate using static IPs and ports, showcasing the foundational setup for microservices without involving advanced tools like Consul 
for service discovery or Nomad for orchestration.

---

## Prerequisites
1. **Tools Installed**:
   - Terraform CLI
   - jq cli `brew install jq`
2. **AWS Setup** (For AWS deployment):
   - An AWS account with access keys configured.
3. **Docker Images**
   - Docker images compiled in last activity and available on docker-hub

---

## Running on AWS

### **Prerequisites**

```sh
export TF_VAR_dockerhub_id=<dockerhub-id>
curl -L https://hub.docker.com/v2/orgs/$TF_VAR_dockerhub_id | jq
# make sure you see your account information in resposne

# set the AWS credentials from doormat (Note: These credentials are short lived hence you may need to redo this steps)
export AWS_ACCESS_KEY_ID=REDACTED
export AWS_SECRET_ACCESS_KEY=REDACTED
export AWS_SESSION_TOKEN=REDACTED
                  
```

---

## Running on AWS

### **Step-by-Step Guide**

### 1. **Navigate to the project folder**
```bash
cd 2-terraform
```

---

### 2. **Initialize Terraform**
Run the following command to download required providers:
```bash
terraform init
```

---

### 2. **Deploy HelloService and ResponseService**
Use Terraform to apply the infrastructure configuration:
```bash
terraform apply
```

Review the changes and type `yes` to confirm.

---

### 6. **Access the Services**
Once deployment is complete, Terraform will output the cli commands for both services:

Example Output:
```plaintext
hello_service_cli = "curl http://<hello-service-dns>:5000/hello | jq"
response_service_cli = "curl http://<response-service-public-ip>:5001/response | jq"
```

Test the services using `curl`:
1. **Test HelloService**:
   ```bash
   curl http://<hello-service-public-ip>:5000/hello | jq
   ```
   Expected Output:
   ```json
   {
       "message": "Hello from HelloService!",
       "response_message": "Bello from ResponseService!"
   }
   ```

2. **Test ResponseService**:
   ```bash
   curl http://<response-service-public-ip>:5001/response | jq
   ```
   Expected Output:
   ```json
   {
       "message": "Bello from ResponseService!"
   }
   ```

---

### 7. **Verify and Debug**
- **Logs**:
  SSH into the instances using your key pair to view logs:
  ```bash
  # reference `ssh_hello_service` in terrform output
  ssh -i minion-key.pem ubuntu@<hello-service-public-ip>
  ```

  Check the logs:
  ```bash
  sudo docker logs hello_service
  > HelloService running on port 5000...

  sudo docker exec -it hello_service /bin/printenv | grep RESPONSE_SERVICE_HOST
  > RESPONSE_SERVICE_HOST=**.**.**.**

  # Observe that IP is same as `response_service` public IP
  ```

- **Connectivity**:
  Ensure HelloService can reach ResponseService via the specified static IP.

---

### 8. **Cleanup**
To remove the infrastructure, use Terraform:
```bash
terraform destroy
```
Confirm by typing `yes`.

---

## Additional Notes
- If you modify the Go files, rebuild the Docker images and push them to Docker Hub.
- Use a consistent naming scheme for your services (e.g., `helloservice:latest` and `responseservice:latest`).

---

## Why This Setup?

  • Simple Learning:
  • Demonstrates inter-service communication without introducing complex tools or concepts.
  • Foundation:
  • Sets up the base infrastructure to expand upon in future parts, where dynamic service discovery and orchestration will be introduced.

## Limitations

  1.  Static IPs and Ports:
  • The hardcoded configuration makes scaling and dynamic updates difficult.
  • It’s not suitable for production environments where services may move between nodes or instances.
  2.  No Load Balancing:
  • Requests to ResponseService always go to a single, predefined address.
  3.  No Security:
  • No authentication, encryption, or secure communication is configured between the services.

## Next Steps

In subsequent parts, we address these limitations by:

  • Introducing Packer: To create reusable AMIs with pre-installed dependencies, simplifying deployment and ensuring consistency.
  • Adding Consul: For dynamic service discovery, allowing services to locate and communicate with each other without hardcoding static IPs (Part 2).
  • Integrating Nomad: For orchestration and scaling, enabling efficient deployment and management of services across multiple nodes (Part 3).
  • Utilizing Vault: For secure secret management, dynamically generating and securely distributing secrets like database credentials (Part 4).

This incremental approach demonstrates how to evolve a simple microservice setup into a robust, production-ready system.