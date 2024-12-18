package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
)

func helloHandler(w http.ResponseWriter, r *http.Request) {
	resp, err := http.Get("http://response-service.service.consul:6060/response") // Static URL
	if err != nil {
		http.Error(w, "Failed to contact ResponseService", http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	response := make(map[string]interface{})
	json.NewDecoder(resp.Body).Decode(&response)

	response["message"] = "Hello from HelloService!"
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func vaultHandler(w http.ResponseWriter, r *http.Request) {
	// Fetch database credentials from Vault
	credentials, err := getVaultCredentials()
	if err != nil {
		http.Error(w, "Failed to fetch database credentials", http.StatusInternalServerError)
		return
	}

	response := map[string]interface{}{
		"message":        "Hello from HelloService!",
		"db_credentials": credentials,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func getVaultCredentials() (map[string]interface{}, error) {
	vaultAddr := os.Getenv("VAULT_ADDR")
	token := os.Getenv("VAULT_TOKEN")

	client := &http.Client{}
	req, _ := http.NewRequest("GET", fmt.Sprintf("%s/v1/database/creds/app-role", vaultAddr), nil)
	req.Header.Add("X-Vault-Token", token)

	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var credentials map[string]interface{}
	body, _ := ioutil.ReadAll(resp.Body)
	json.Unmarshal(body, &credentials)

	return credentials, nil
}

func main() {
	http.HandleFunc("/hello", helloHandler)
	http.HandleFunc("/hello_vault", vaultHandler)
	fmt.Println("HelloService running on port 5000...")
	log.Fatal(http.ListenAndServe(":5000", nil))
}
