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
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace"
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

	var otelpEndpoint string
	if os.Getenv("ENV") == "DEV" {
		otelpEndpoint = "localhost:4318"
	} else {
		otelpEndpoint = "jaeger-otlp.service.consul:4318"
	}

	client := otlptracehttp.NewClient(
		otlptracehttp.WithEndpoint(otelpEndpoint), // Set the correct endpoint
		otlptracehttp.WithInsecure(),              // Use HTTP instead of HTTPS
	)

	// Create an OTLP exporter
	exporter, err := otlptrace.New(ctx, client)
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

	var responseServiceURL string
	if os.Getenv("ENV") == "DEV" {
		responseServiceURL = "http://localhost:6060/response"
	} else {
		responseServiceURL = "http://response-service.service.consul:6060/response"
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

	response["message"] = "Hello from HelloService!"
	successfulResponses.Inc() // Increment successful responses

	// Send response
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)

	// Add HTTP status code to the span
	span.SetAttributes(semconv.HTTPStatusCodeKey.Int(http.StatusOK))
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"status": "healthy"})
}

func main() {
	initTracer()

	http.Handle("/metrics", promhttp.Handler())

	http.HandleFunc("/hello", helloHandler)

	http.HandleFunc("/health", healthHandler)

	fmt.Println("HelloService running on port 5050...")
	log.Fatal(http.ListenAndServe(":5050", nil))
}
