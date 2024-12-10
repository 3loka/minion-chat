
# Part 3: Consul Integration

## Background
Our Hello app is already running with following limitations
1. **Microservices Discovery**: Service discovery is a big challenge
2. **Limited Availability**: Hardcoded IPs makes the setup extremly difficult to `scale-up`, `scale-down`, hence application is not HA.
3. **Limited Scalability**: Hardcoded IPs makes the setup extremly difficult to `scale-up`, `scale-down`.
4. **No Fault Tolerance**: Services may fail without recovery mechanisms.
5. **Insecure Secret Management**: Secrets are hardcoded and not securely handled.
6. **Manual Application lifecyle**: Application lifecycle is difficult to maintain using terraform/manually. The compute is not utilized efficiently.
7. **Hardcoded Response**

## Overview
This section introduces HashiCorp Consul to enhance service discovery and fault tolerance for HelloService and ResponseService:
- With Consul's Service Discovery feature, hardcoded IPs are no longer necessary; services can dynamically discover each other using Consul's DNS capabilities.
- It enables seamless scaling by eliminating the need for internal load balancers for service-to-service communication.
- Services can scale up or scale down without requiring additional configuration or reconfiguration.
- Consul performs health checks, automatically removing unhealthy service instances from DNS records to prevent discovery of faulty instances.

## Prerequisites
1. **Tools Installed**:
   - Terraform CLI
   - jq CLI
2. **AWS Setup** (For AWS deployment):
   - An AWS account with access keys configured.

## Steps to Run

1. **Navigate to the Part 2 directory**:
   ```bash
   cd 3-consul
   ```
2. **Replace the hardcoded IPs with DNS**
   Apply below changes

   ./HelloService/main.go
   ```diff
   - resp, err := http.Get("http://localhost:6060/response") // Static URL
   + resp, err := http.Get("http://response-service.service.consul:6060/response") // Static URL
   ```

3. **Uniquely Indentifying the AWS instance**
   While we will attempt to scale up the Response Service, we need to identify which instance of Resonse Service serves us!
   
   From
   ```golang
   func responseHandler(w http.ResponseWriter, r *http.Request) {
      response := map[string]interface{}{
         "response_message": "Bello from ResponseService!",
      }

      w.Header().Set("Content-Type", "application/json")
      json.NewEncoder(w).Encode(response)

      // register your progress in leadership board
      err := registerProgress("terraform")
      if err != nil {
         // set http status code to 500
         http.Error(w, fmt.Sprintf("Failed to register progress %v", err), http.StatusInternalServerError)
         return
      }
   }
   ```

   To
   ```golang
   func responseHandler(w http.ResponseWriter, r *http.Request) {
      response := make(map[string]interface{})
      instanceID, err := getInstaceID()
      if err != nil {
         http.Error(w, "Failed to contact ResponseService", http.StatusInternalServerError)
         return
      }
      response["response_message"] = fmt.Sprintf("Bello from ResponseService %s!", instanceID)

      w.Header().Set("Content-Type", "application/json")
      json.NewEncoder(w).Encode(response)

      // register your progress in leadership board
      err = registerProgress("consul")
      if err != nil {
         // set http status code to 500
         http.Error(w, fmt.Sprintf("Failed to register progress %v", err), http.StatusInternalServerError)
         return
      }
   }

   func getInstaceID() (string, error) {
      metadataURL := "http://169.254.169.254/latest/meta-data/instance-id" // AWS metadata URL for instance ID
      resp, err := http.Get(metadataURL)
      if err != nil {
         log.Fatalf("Failed to fetch instance ID: %v", err)
         return "", err
      }
      defer resp.Body.Close()

      id, err := ioutil.ReadAll(resp.Body)
      if err != nil {
         log.Fatalf("Failed to read response body for instance ID: %v", err)
         return "", err
      }

      return string(id), nil
   }
   ```

3. **Reading message dynamically from Consul KV**

   So far we are reading a hardcoded response, lets give more control to Kevin to control the response!

   ./ResponseService/main.go
   From
   ```golang
   func responseHandler(w http.ResponseWriter, r *http.Request) {
      response := make(map[string]interface{})
      instanceID, err := getInstaceID()
      if err != nil {
         http.Error(w, "Failed to contact ResponseService", http.StatusInternalServerError)
         return
      }
      response["response_message"] = fmt.Sprintf("Bello from ResponseService %s!", instanceID)

      w.Header().Set("Content-Type", "application/json")
      json.NewEncoder(w).Encode(response)

      // register your progress in leadership board
      err = registerProgress("consul")
      if err != nil {
         // set http status code to 500
         http.Error(w, fmt.Sprintf("Failed to register progress %v", err), http.StatusInternalServerError)
         return
      }
   }

   ```

   To
   ```golang
   func responseHandler(w http.ResponseWriter, r *http.Request) {
      response := make(map[string]interface{})
      instanceID, err := getInstaceID()
      if err != nil {
         http.Error(w, "Failed to contact ResponseService", http.StatusInternalServerError)
         return
      }
      response["response_message"] = fmt.Sprintf("Bello from ResponseService %s!", instanceID)

      // Fetch minion phrases from Consul KV store
      phrases, err := getMinionPhrases()
      if err != nil {
         http.Error(w, "Failed to contact ResponseService", http.StatusInternalServerError)
         return
      }
      response["minion_phrases"] = phrases

      w.Header().Set("Content-Type", "application/json")
      json.NewEncoder(w).Encode(response)

      // register your progress in leadership board
      err = registerProgress("consul")
      if err != nil {
         // set http status code to 500
         http.Error(w, fmt.Sprintf("Failed to register progress %v", err), http.StatusInternalServerError)
         return
      }
   }

   // Reading from Consul KV store
   func getMinionPhrases() ([]string, error) {
      resp, err := http.Get("http://consul.service.consul:8500/v1/kv/minion_phrases?raw")
      if err != nil {
         log.Printf("Failed to fetch Minion phrases from kv store: %v", err)
         return nil, err
      }
      defer resp.Body.Close()

      if resp.StatusCode != http.StatusOK {
         log.Printf("Unexpected status code: %d", resp.StatusCode)
         return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode)
      }

      body, err := io.ReadAll(resp.Body)
      if err != nil {
         log.Printf("Failed to read response body: %v", err)
         return nil, err
      }

      var phrases []string
      err = json.Unmarshal(body, &phrases)
      if err != nil {
         log.Printf("Failed to unmarshal response body: %v", err)
         return nil, err
      }

      return phrases, nil
   }
   ```

4. **Self registering the service to Consul Server**

   For consul to discover the instances dynamically, the instance need to register itself to Consul at startup!
   ./ResponseService/main.go
   From
   ```golang
   func main() {
      http.HandleFunc("/response", responseHandler)
      fmt.Println("ResponseService running on port 6060...")
      log.Fatal(http.ListenAndServe(":6060", nil))
   }
   ```

   To
   ```golang
   func main() {
      // register to consul
      registerService("response-service", 6060, "response")

      http.HandleFunc("/response", responseHandler)
      fmt.Println("ResponseService running on port 6060...")
      log.Fatal(http.ListenAndServe(":6060", nil))
   }

   func registerService(service string, port int, healthEp string) {
      privateIP := getPrivateIPAddress()

      // Define the service registration data
      serviceRegistration := map[string]interface{}{
         "ID":      fmt.Sprintf("%s-%s", service, privateIP), // Unique ID for this instance
         "Name":    service,                                  // Service name
         "Address": privateIP,                                // Use the private IP of the instance
         "Port":    port,                                     // Port this service is running on
         "Check": map[string]interface{}{ // Health check configuration
            "HTTP":     fmt.Sprintf("http://%s:%d/%s", privateIP, port, healthEp), // Health check endpoint
            "Interval": "10s",                                                     // Frequency of health checks
            "Timeout":  "2s",                                                      // Timeout for each health check
         },
      }
      data, err := json.Marshal(serviceRegistration)
      if err != nil {
         log.Fatalf("Failed to marshal service registration data: %v", err)
      }
      req, err := http.NewRequest(http.MethodPut, "http://consul.service.consul:8500/v1/agent/service/register", bytes.NewBuffer(data))
      if err != nil {
         log.Fatalf("Failed to create HTTP request: %v", err)
      }
      req.Header.Set("Content-Type", "application/json")
      resp, err := (&http.Client{}).Do(req)
      if err != nil || resp.StatusCode != http.StatusOK {
         log.Fatalf("Failed to register service with Consul. Status: %s", resp.Status)
      }
      defer resp.Body.Close()
      fmt.Println("Service registered successfully with Consul.")
   }
   ```

5. **Set the minion phrase in Consul KV**
   
   To add minion phrase in Cosnul KV, SSH into one of the client machine and execute
   ```sh
   curl --request PUT --data '["Bello!", "Poopaye!", "Tulaliloo ti amo!"]' http://consul.service.consul:8500/v1/kv/minion_phrases
   ```

6. **Push Docker Images to Docker Hub**

   ```bash
   DOCKER_DEFAULT_PLATFORM=linux/amd64  docker-compose build
   DOCKER_DEFAULT_PLATFORM=linux/amd64  docker-compose push
   ```
7. **Building AMI using Packer**
   ```bash
   packer init -var-file=variables.hcl image.pkr.hcl
   packer build -var-file=variables.hcl image.pkr.hcl
   ```

   Record the AMI id, we will need it in next step

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

7. **Test the Services**:
   - Test **HelloService**:
     ```bash
     curl http://<hello-service>:5050/hello | jq
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

8. **Access Consul UI**:
   - Open the Consul UI in a browser:
     ```plaintext
     http://localhost:8500
     ```
9. **SSH to the 1st Response Service**:
   - use ssh command suggested in terraform output and connect to the instance suggested by `Hello Service response`
   - Testing DNS:
     ```bash
     curl consul.service.consul:8500
     <a href="/ui/">Moved Permanently</a>.

     curl response-service.service.consul:6060/response | jq
     {
      "message": "Hello from HelloService!",
      "minion_phrases": [
         "Bello!",
         "Poopaye!",
         "Tulaliloo ti amo!"
      ],
      "response_message": "Bello from ResponseService i-05506b6e36d25223a!"
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
10. **DIY**:
   - Read the code and identify how to add `Tank yu` to the `minion_phrases`

## Key Points
- Dynamic service discovery: HelloService resolves ResponseService using Consul.
- Centralized configuration via KV store.
- Fault tollerant via consul circuit breaker
