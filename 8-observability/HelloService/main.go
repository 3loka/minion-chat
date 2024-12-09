package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.21.0"
	"go.opentelemetry.io/otel/trace"
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
	tracer trace.Tracer
)

func init() {
	// Register Prometheus metrics
	prometheus.MustRegister(totalRequests)
	prometheus.MustRegister(successfulResponses)
	prometheus.MustRegister(failedResponses)
	prometheus.MustRegister(requestDuration)
}

func initTracer() {
	ctx := context.Background()

	// Create an OTLP HTTP exporter
	exporter, err := otlptracehttp.New(ctx)
	if err != nil {
		log.Fatalf("Failed to create OTLP trace exporter: %v", err)
	}

	// Create a resource with service name and other metadata
	res, err := resource.New(ctx,
		resource.WithAttributes(
			semconv.ServiceNameKey.String("hello-service"),
		),
	)
	if err != nil {
		log.Fatalf("Failed to create resource: %v", err)
	}

	// Create a tracer provider with the OTLP exporter and resource
	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter),
		sdktrace.WithResource(res),
	)

	// Register the tracer provider globally
	otel.SetTracerProvider(tp)

	// Set the tracer
	tracer = otel.Tracer("hello-service")
}

func helloHandler(w http.ResponseWriter, r *http.Request) {
	totalRequests.Inc() // Increment total requests

	// Start measuring request duration
	timer := prometheus.NewTimer(requestDuration)
	defer timer.ObserveDuration()

	// Start OpenTelemetry span
	ctx, span := tracer.Start(r.Context(), "helloHandler")
	defer span.End()

	// Check for "DEV" environment variable
	var responseServiceURL string
	if os.Getenv("ENV") == "DEV" {
		responseServiceURL = "http://localhost:5001/response"
	} else {
		responseServiceURL = "http://response-service.service.consul:5001/response"
	}

	// Call the ResponseService
	client := http.Client{}
	req, _ := http.NewRequestWithContext(ctx, "GET", responseServiceURL, nil)
	resp, err := client.Do(req)
	if err != nil {
		log.Printf("Failed to contact ResponseService: %v", err)
		failedResponses.Inc() // Increment failed responses
		span.RecordError(err)
		http.Error(w, "Failed to contact ResponseService", http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	var response map[string]interface{}
	err = json.NewDecoder(resp.Body).Decode(&response)
	if err != nil {
		log.Printf("Failed to decode response: %v", err)
		failedResponses.Inc()
		span.RecordError(err)
		http.Error(w, "Failed to decode ResponseService response", http.StatusInternalServerError)
		return
	}

	// Add HelloService-specific message
	response["message"] = "Hello from HelloService!"
	successfulResponses.Inc() // Increment successful responses

	// Send response
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)

	// Add HTTP status code to the span
	span.SetAttributes(semconv.HTTPStatusCodeKey.Int(http.StatusOK))
}

func main() {
	initTracer() // Initialize OpenTelemetry tracing

	// Register Prometheus metrics endpoint
	http.Handle("/metrics", promhttp.Handler())

	// Register hello handler
	http.HandleFunc("/hello", helloHandler)

	fmt.Println("HelloService running on port 5000...")
	log.Fatal(http.ListenAndServe(":5000", nil))
}
