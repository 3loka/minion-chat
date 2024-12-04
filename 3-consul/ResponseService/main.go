package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
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

func main() {
	http.HandleFunc("/response", responseHandler)
	fmt.Println("ResponseService running on port 5001...")
	log.Fatal(http.ListenAndServe(":5001", nil))
}
