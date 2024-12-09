package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	// Define Prometheus metrics
	totalRequests = prometheus.NewCounter(
		prometheus.CounterOpts{
			Name: "response_service_total_requests",
			Help: "Total number of requests received by ResponseService",
		},
	)
	successfulResponses = prometheus.NewCounter(
		prometheus.CounterOpts{
			Name: "response_service_successful_responses",
			Help: "Total number of successful responses by ResponseService",
		},
	)
	failedResponses = prometheus.NewCounter(
		prometheus.CounterOpts{
			Name: "response_service_failed_responses",
			Help: "Total number of failed responses by ResponseService",
		},
	)
	requestDuration = prometheus.NewHistogram(
		prometheus.HistogramOpts{
			Name:    "response_service_request_duration_seconds",
			Help:    "Histogram of response times for requests to ResponseService",
			Buckets: prometheus.DefBuckets,
		},
	)
)

func init() {
	// Register metrics with Prometheus
	prometheus.MustRegister(totalRequests)
	prometheus.MustRegister(successfulResponses)
	prometheus.MustRegister(failedResponses)
	prometheus.MustRegister(requestDuration)
}

func responseHandler(w http.ResponseWriter, r *http.Request) {
	totalRequests.Inc() // Increment the total requests counter

	// Start measuring request duration
	timer := prometheus.NewTimer(requestDuration)
	defer timer.ObserveDuration()

	// Fetch Minion phrases from Consul KV
	phrases, err := getMinionPhrases()
	var response map[string]interface{}
	if err != nil {
		log.Printf("Minion phrases fetch failed: %v", err)
		failedResponses.Inc() // Increment failed responses counter
		response = map[string]interface{}{
			"response_message": "Bello from ResponseService!",
		}
	} else {
		response = map[string]interface{}{
			"response_message": "Bello from ResponseService!",
			"minion_phrases":   phrases,
		}
	}

	if instanceID := os.Getenv("INSTANCE_ID"); instanceID != "" {
		response["response_message"] = fmt.Sprintf("Bello from ResponseService %s!", instanceID)
	}

	successfulResponses.Inc() // Increment successful responses counter

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
	// Register Prometheus metrics endpoint
	http.Handle("/metrics", promhttp.Handler())

	http.HandleFunc("/response", responseHandler)

	fmt.Println("ResponseService running on port 5001...")
	log.Fatal(http.ListenAndServe(":5001", nil))
}
