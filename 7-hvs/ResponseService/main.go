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
)

func responseHandler(w http.ResponseWriter, r *http.Request) {
	// Fetch Minion phrases from Consul KV
	phrases, err := getMinionPhrases()
	var response map[string]interface{}
	if err != nil {
		log.Printf("Minion phrases fetch failed: %v", err)
		response = map[string]interface{}{
			"response_message": "Bello from ResponseService!",
		}
	} else {
		response = map[string]interface{}{
			"response_message": "Bello from ResponseService!",
			"minion_phrases":   phrases,
		}
	}

	hvsResponse, err := getSecretFromHVS()
	response["hvs_response"] = hvsResponse

	// Check if the environment variable INSTANCE_ID is set
	if instanceID := os.Getenv("INSTANCE_ID"); instanceID != "" {
		response["response_message"] = fmt.Sprintf("Bello from ResponseService %s!", instanceID)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

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
	http.HandleFunc("/response", responseHandler)
	fmt.Println("ResponseService running on port 5001...")
	fmt.Println(os.Environ())
	log.Fatal(http.ListenAndServe(":5001", nil))
}
