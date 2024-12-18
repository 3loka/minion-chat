package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"net/url"
	"os"
	"strings"
)

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

	hvsResponse, err := getSecretFromHVS()
	response["hvs_response"] = hvsResponse

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)

	// register your progress in leadership board
	err = registerProgress("hvs")
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

// getPrivateIPAddress fetches the private IP address of the instance
func getPrivateIPAddress() (string, error) {
	metadataURL := "http://169.254.169.254/latest/meta-data/local-ipv4" // AWS metadata URL for private IP
	resp, err := http.Get(metadataURL)
	if err != nil {
		log.Fatalf("Failed to fetch private IP address: %v", err)
		return "", err
	}
	defer resp.Body.Close()

	ip, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		log.Fatalf("Failed to read response body for private IP address: %v", err)
		return "", err
	}

	return string(ip), nil
}

// Register progress in leadership board
func registerProgress(game string) error {
	// register progress in leadership board
	url := "http://leaderboard.ashesh-vidyut.sbx.hashidemos.io/api/"
	// make a post call with header
	req, err := http.NewRequest("POST", url, nil)
	if err != nil {
		fmt.Println(err)
	}
	req.Header.Set("Content-Type", "application/json")
	// UGLY WAY OF HANDLING SECRET, for demo purpose only
	req.Header.Set("token", "ECD9823E-6E7E-42F0-BD72-1CA381098C0D")

	// get dockerhub_id from environment variable
	dockerhub_id := os.Getenv("TF_VAR_dockerhub_id")
	if dockerhub_id == "" {
		// error handling
		return fmt.Errorf("TF_VAR_dockerhub_id not set")
	}

	payload := fmt.Sprintf(`{"user": "%s", "game": "%s"}`, dockerhub_id, game)
	req.Body = io.NopCloser(strings.NewReader(payload))

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("Failed to register progress %v", err)
	}
	defer resp.Body.Close()

	// read response body
	msg, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("Failed to read response body %v", err)
	}
	fmt.Println(string(msg))

	return nil
}

func getSecretFromHVS() (map[string]interface{}, error) {
	clientID := os.Getenv("HCP_CLIENT_ID")
	clientSecret := os.Getenv("HCP_CLIENT_SECRET")
	if clientID == "" || clientSecret == "" {
		return nil, fmt.Errorf("please set the HCP_CLIENT_ID and HCP_CLIENT_SECRET environment variables")
	}

	// Define the endpoint and parameters
	authURL := "https://auth.idp.hashicorp.com/oauth2/token"
	data := url.Values{}
	data.Set("client_id", clientID)
	data.Set("client_secret", clientSecret)
	data.Set("grant_type", "client_credentials")
	data.Set("audience", "https://api.hashicorp.cloud")

	// Create the POST request
	req, err := http.NewRequest("POST", authURL, bytes.NewBufferString(data.Encode()))
	if err != nil {
		return nil, fmt.Errorf("Error creating request: %v\n", err)
	}

	// Set headers
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	// Execute the request
	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("Error sending request: %v\n", err)
	}
	defer resp.Body.Close()

	// Read the response body
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("Error reading response: %v\n", err)
	}

	// Parse the JSON response
	var response map[string]interface{}
	err = json.Unmarshal(body, &response)
	if err != nil {
		fmt.Printf("Error parsing JSON: %v\n", err)
		return nil, fmt.Errorf("Error parsing JSON: %v\n", err)
	}

	// Extract the access token
	accessToken, ok := response["access_token"].(string)
	if !ok {
		return nil, fmt.Errorf("Error access token not found in the response.")
	}

	orgId := os.Getenv("HCP_ORGANIZATION_ID")
	projectId := os.Getenv("HCP_PROJECT_ID")

	// Define the API endpoint
	url := fmt.Sprintf("https://api.cloud.hashicorp.com/secrets/2023-11-28/organizations/%s/projects/%s/apps/minion-app/secrets:open", orgId, projectId)

	// Create a new GET request
	req, rerr := http.NewRequest("GET", url, nil)
	if rerr != nil {
		fmt.Printf("Error creating request: %v\n", err)
		return nil, err
	}

	// Set the Authorization header
	req.Header.Set("Authorization", "Bearer "+accessToken)

	// Execute the request
	client = &http.Client{}
	resp, reserr := client.Do(req)
	if reserr != nil {
		return nil, fmt.Errorf("Error sending request: %v\n", err)
	}
	defer resp.Body.Close()

	// Check the HTTP status code
	if resp.StatusCode != http.StatusOK {
		fmt.Printf("Request failed with status code: %d\n", resp.StatusCode)
		body, _ := ioutil.ReadAll(resp.Body)
		fmt.Printf("Response: %s\n", body)
		return nil, fmt.Errorf("Unexpected status code: %d\n", resp.StatusCode)
	}

	// Read and print the response body
	body, err = ioutil.ReadAll(resp.Body)
	if err != nil {
		fmt.Printf("Error reading response: %v\n", err)
		return nil, fmt.Errorf("Error reading response: %v\n", err)
	}

	// Parse the response body into a map[string]interface{}
	var responseMap map[string]interface{}
	err = json.Unmarshal(body, &responseMap)
	if err != nil {
		fmt.Printf("Error parsing JSON response: %v\n", err)
		return nil, fmt.Errorf("Error parsing JSON: %v\n", err)
	}

	return responseMap, nil
}

func main() {
	// register to consul
	registerService("response-service", 6060, "response")

	http.HandleFunc("/response", responseHandler)
	fmt.Println("ResponseService running on port 6060...")
	log.Fatal(http.ListenAndServe(":6060", nil))
}

func registerService(service string, port int, healthEp string) {
	privateIP, err := getPrivateIPAddress()
	if err != nil {
		log.Fatalf("Failed to get private IP address: %v", err)
	}

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
