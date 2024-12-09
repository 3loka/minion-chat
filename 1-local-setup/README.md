
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
   - Docker and Docker Compose(For local setup)
   - jq cli `brew install jq`

---

## Running Locally

### **Prerequisites**
Ensure Docker is installed along with docker-compose and running on your machine.

```sh
export TF_VAR_dockerhub_id=<dockerhub-id>
curl -L https://hub.docker.com/v2/orgs/$TF_VAR_dockerhub_id | jq
# make sure you see your account information in resposne
```

### **Step-by-Step Guide**

#### 1. **Navigate to the Project Directory**
Navigate to the directory containing the `main.go` files for HelloService and ResponseService.

```bash
cd 1-local-setup
```

#### 2. **Build and Run Docker Images**
Build Docker images for HelloService and ResponseService.

```bash
docker-compose up
```

#### 3. **Test the Services**

1. **Test HelloService**:
   Open a terminal and run:
   ```bash
   curl http://localhost:9999/hello | jq
   ```
   Expected Output:
   ```json
   {
       "message": "Hello from HelloService!",
       "response_message": "Bello from ResponseService!"
   }
   ```

2. **Test ResponseService**:
   Open a terminal and run:
   ```bash
   curl http://localhost:5001/response | jq
   ```
   Expected Output:
   ```json
   {
       "message": "Bello from ResponseService!"
   }
   ```

#### 4. **Verify and Debug**
- Check the running Docker containers:
  ```bash
  docker ps
  ```
- View container logs:
  ```bash
  docker logs <container-id>
  ```

#### 5. **Stop and Cleanup**
To stop and remove the running containers:
```bash
docker-compose stop
```

#### 6. **Push Docker Images to Docker Hub**

```bash
DOCKER_DEFAULT_PLATFORM=linux/amd64  docker-compose build
DOCKER_DEFAULT_PLATFORM=linux/amd64  docker-compose push
```

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