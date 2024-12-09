package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	// Prometheus metrics
	totalRequests = prometheus.NewCounter(
		prometheus.CounterOpts{
			Name: "hello_service_total_requests",
			Help: "Total number of requests received by HelloService",
		},
	)
	successfulResponses = prometheus.NewCounter(
		prometheus.CounterOpts{
			Name: "hello_service_successful_responses",
			Help: "Total number of successful responses by HelloService",
		},
	)
	failedResponses = prometheus.NewCounter(
		prometheus.CounterOpts{
			Name: "hello_service_failed_responses",
			Help: "Total number of failed responses by HelloService",
		},
	)
	requestDuration = prometheus.NewHistogram(
		prometheus.HistogramOpts{
			Name:    "hello_service_request_duration_seconds",
			Help:    "Histogram of response times for requests to HelloService",
			Buckets: prometheus.DefBuckets,
		},
	)
)

func init() {
	prometheus.MustRegister(totalRequests)
	prometheus.MustRegister(successfulResponses)
	prometheus.MustRegister(failedResponses)
	prometheus.MustRegister(requestDuration)
}

func helloHandler(w http.ResponseWriter, r *http.Request) {
	totalRequests.Inc() // Increment the total requests counter

	// Start measuring request duration
	timer := prometheus.NewTimer(requestDuration)
	defer timer.ObserveDuration()

	// Call ResponseService
	// Determine which URL to use
	// Determine which URL to use
	var url string
	if os.Getenv("ENV") == "DEV" {
		url = "http://localhost:5001/response"
	} else {
		url = "http://response-service.service.consul:5001/response"
	}

	resp, err := http.Get(url)
	if err != nil {
		failedResponses.Inc() // Increment failed responses counter
		http.Error(w, "Failed to contact ResponseService", http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	var response map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
		failedResponses.Inc() // Increment failed responses counter
		http.Error(w, "Failed to decode ResponseService response", http.StatusInternalServerError)
		return
	}

	// Enhance response and send back to client
	response["message"] = "Hello from HelloService!"
	successfulResponses.Inc() // Increment successful responses counter

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func main() {
	// Register Prometheus metrics endpoint
	http.Handle("/metrics", promhttp.Handler())

	http.HandleFunc("/hello", helloHandler)

	fmt.Println("HelloService running on port 5000...")
	log.Fatal(http.ListenAndServe(":5000", nil))
}
