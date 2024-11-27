package main

import (
    "encoding/json"
    "fmt"
    "io/ioutil"
    "log"
    "net/http"
    "os"
)

func responseHandler(w http.ResponseWriter, r *http.Request) {
    // Fetch database credentials from Vault
    credentials, err := getVaultCredentials()
    if err != nil {
        http.Error(w, "Failed to fetch database credentials", http.StatusInternalServerError)
        return
    }

    response := map[string]interface{}{
        "message":       "Bello from ResponseService!",
        "db_credentials": credentials,
    }

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(response)
}

func getVaultCredentials() (map[string]interface{}, error) {
    vaultAddr := os.Getenv("VAULT_ADDR")
    token := os.Getenv("VAULT_TOKEN")

    client := &http.Client{}
    req, _ := http.NewRequest("GET", fmt.Sprintf("%s/v1/database/creds/my-role", vaultAddr), nil)
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
    http.HandleFunc("/response", responseHandler)
    fmt.Println("ResponseService running on port 5001...")
    log.Fatal(http.ListenAndServe(":5001", nil))
}