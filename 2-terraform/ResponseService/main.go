package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
)

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

func main() {
	http.HandleFunc("/response", responseHandler)
	fmt.Println("ResponseService running on port 6060...")
	log.Fatal(http.ListenAndServe(":6060", nil))
}
