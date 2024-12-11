
# Steps to Run Part 1 (Basic Setup)

## Background
Kevin, our minion friend, wants to deploy a Hello app that will be accessible to other Minion friends over the internet.

## Overview
This setup involves deploying two simple microservices, **HelloService** and **ResponseService**, to demonstrate basic inter-service communication:  
- **HelloService** serves as the entry point, handling requests to its `/hello` endpoint. It retrieves a message from **ResponseService** at its `/response` endpoint and combines the two messages into a single JSON response.
  
- **HelloService** returns:  
  `"Hello from HelloService!"`  
  along with the response from ResponseService:  
  `"Bello from ResponseService!"`

These services communicate using static IPs and ports, highlighting the foundational concepts of microservice architecture.

---

## Prerequisites
Ensure you have the following tools installed:  
- `jq` CLI  
- `golang`  
- `curl` CLI  
- `gh` CLI  

---

## Running Locally

### **Step-by-Step Guide**

```bash
# Clone the repository
mkdir -p ~/git && cd ~/git
gh repo clone 3loka/minion-chat
cd ./minion-chat

# Set up Docker Hub credentials
export TF_VAR_dockerhub_id=<dockerhub-id>
curl -L https://hub.docker.com/v2/orgs/$TF_VAR_dockerhub_id | jq
# make sure you see your account information in response

# Start the services
cd 1-local-setup
go run ./HelloService/main.go > /dev/null 2>&1 &
go run ./ResponseService/main.go > /dev/null 2>&1 &


```

#### 3. **Test the Services**

1. **Test HelloService**:
   Open a terminal and run:
   ```bash
   curl http://localhost:5050/hello | jq
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
   curl http://localhost:6060/response | jq
   ```
   Expected Output:
   ```json
   {
       "message": "Bello from ResponseService!"
   }
   ```

#### 5. **Stop and Cleanup**
To stop and remove the running containers:
```bash
# Find and kill the running services
jobs -l
kill <pid>

lsof -i :5050
kill <pid>

lsof -i :6060
kill <pid>
```

---

## Take aways?
  • Simple Learning: Demonstrates inter-service communication without introducing complex tools or concepts.


## Limitations
1. **Unreliable Infrastructure**: Single-instance services with hardcoded IPs.
2. **Lack of High Availability**: Only one instance of each service.
3. **Limited Scalability**: Hardcoded IPs makes the setup extremly difficult to `scale-up`, `scale-down`.
4. **No Fault Tolerance**: Services may fail without recovery mechanisms.
5. **Insecure Secret Management**: Secrets are hardcoded and not securely handled.
6. **Rigid Deployment**: Fixed configurations with minimal flexibility.