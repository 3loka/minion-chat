
# Part 2: Say Hello to terrafom and AWS

## Background

Our Hello app is already running with following limitations
1. **Unreliable Infrastructure**: Single-instance services with hardcoded IPs.
2. **No release Package**: Code is deployed directly by compiling code. This limits the Portability, Env Consistencey, Faster Deployment, Scalability, Isolation, Enhanced Security, Version Controlled...
3. **Lack of High Availability**: Only one instance of each service.
4. **Limited Scalability**: Hardcoded IPs makes the setup extremly difficult to `scale-up`, `scale-down`.
5. **No Fault Tolerance**: Services may fail without recovery mechanisms.
6. **Insecure Secret Management**: Secrets are hardcoded and not securely handled.
7. **Rigid Deployment**: Fixed configurations with minimal flexibility.


## Overview
We will be targetting to solve the problem of unreliable infra by deploying this app in AWS cloud.

The other big Challenge with using cloud is Infrastructure Management.
#### List if infrastructure items
- Auto selecting the latest ubuntu image.
- Creating Security Group with ingress and egress defined.
- 2 AWS Instance to host the application with docker installed
- One private key to SSH the two AWS Instance
- Inject the environment variable `TF_VAR_dockerhub_id` into Response Service
- Configuring and intalling necessary applications.
- (We will do it manually) Auto running the application

# Proposal
AWS Cloud platformn provides a reliable infrasture but there are lot of componets and configurations to manage manually. Terraform is popular IAC platform to manage the infrastructure as a code.

---

## Infrastructure on AWS

### 1. **Understanding Terraform**
Terraform is an Infrastructure as Code (IaC) tool developed by HashiCorp. It allows you to define, provision, and manage cloud infrastructure using declarative configuration files. Terraform is cloud-agnostic and can manage infrastructure for major providers like AWS, Azure, GCP, etc., as well as on-prem solutions.

Here’s a breakdown of the three main files often used in a Terraform project:

1. **main.tf**
This is the core file where you define the infrastructure resources. It includes the provider configuration, resource blocks, and possibly some modules. It essentially describes what infrastructure you want.

2. **variables.tf**
This file is used to declare variables that can be referenced in the main.tf file. Variables allow for flexible and reusable configurations.

3. **output.tf**
This file defines outputs that Terraform will display after applying the configuration. Outputs are useful for retrieving information about created resources.

### 2. **Setup and AWS Auth**
```bash
cd 2-terraform
```

Open a terminal and run below commands in sequence
```bash

# Set up Docker Hub credentials  
export TF_VAR_dockerhub_id=<dockerhub-id>
curl -L https://hub.docker.com/v2/orgs/$TF_VAR_dockerhub_id | jq
# make sure you see your account information in resposne

# set the AWS credentials from doormat (Note: These credentials are short lived hence you may need to redo this steps)
export AWS_ACCESS_KEY_ID=REDACTED
export AWS_SECRET_ACCESS_KEY=REDACTED
export AWS_SESSION_TOKEN=REDACTED
                  
```

### 3. **Spinning up the Infrastructure**

```bash
terraform init
terraform apply

```

Sample Outputs:
```
env = <<EOT
    export HELLO_SERVICE=3.84.149.170
    export RESPONSE_SERVICE=54.175.84.27

EOT
hello_service_cli = "curl http://3.84.149.170:5050/hello | jq"
response_service_cli = "curl http://54.175.84.27:6060/response | jq"
response_service_private_ip = "172.31.26.141"
```

### 4. **Setting the environment**
Copy the env section from terraform output and execute in terminal

### 4. **HARDCODING the IPs**
From the output of the `terraform apply`, select the private IP address of response service suggested by output `response_service_private_ip`, say it is `172.0.0.1`. 
Apply this to code as shown below.

./HelloService/main.go 
```diff
- resp, err := http.Get("http://localhost:6060/response") // Static URL
+ resp, err := http.Get("http://172.0.0.1:6060/response") // Static URL

```

### 5. **Push Docker Images to Docker Hub**

```bash
DOCKER_DEFAULT_PLATFORM=linux/amd64  docker-compose build
DOCKER_DEFAULT_PLATFORM=linux/amd64  docker-compose push
```

### 5. **Manual deploying the Response Service**
Run in new terminal
```bash
ssh -i "minion-key.pem" ubuntu@$RESPONSE_SERVICE
docker run -d --name 'response_service' -p -e TF_VAR_dockerhub_id=${TF_VAR_dockerhub_id} 6060:6060 ${TF_VAR_dockerhub_id}/responseservice:latest
sudo docker logs response_service
# Listening on port 6060...

exit
```


### 5. **Manual deploying the Hello Service**
Run in new terminal
```bash
ssh -i "minion-key.pem" ubuntu@$HELLO_SERVICE
docker run -d --name 'hello_service' -p 5050:5050 ${TF_VAR_dockerhub_id}/responseservice:latest
sudo docker logs response_service
# Listening on port 5050...

exit
```

---


### 6. **Access the Services**

1. **Test HelloService**:
Run in new terminal
```bash
curl http://$HELLO_SERVICE:5050/hello | jq
```

Expected Output:
```json
{
    "message": "Hello from HelloService!",
    "response_message": "Bello from ResponseService!"
}
```

2. **Test ResponseService**:
Run in new terminal
```bash
curl http://$RESPONSE_SERVICE:6060/response | jq
```

Expected Output:
```json
{
    "message": "Bello from ResponseService!"
}
```

---

## Take aways?
  • Cloud provides reliable insfrastructure
  • Complex infra can be easily managed using Terraform


## Limitations
1. **Microservices Discovery**: Service discovery is a big challenge
2. **Limited Availability**: Hardcoded IPs makes the setup extremly difficult to `scale-up`, `scale-down`, hence application is not HA.
3. **Limited Scalability**: Hardcoded IPs makes the setup extremly difficult to `scale-up`, `scale-down`.
4. **No Fault Tolerance**: Services may fail without recovery mechanisms.
5. **Hardcoded responses**: There is need for a persistent store for the application to generate the response dynamically without changing the code everytime.
6. **Insecure Secret Management**: Secrets are hardcoded and not securely handled.
7. **Manual Application Management**: Application lifecycle is difficult to maintain using terraform/manually. The compute is not utilized efficiently.
8. **Lack of Resource Optimization** One AWS Instance per Service Instance is not the efficient and cost effective way to run production.