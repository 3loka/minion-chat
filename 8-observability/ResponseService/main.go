package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
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
			semconv.ServiceNameKey.String("response-service"),
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
	tracer = otel.Tracer("response-service")
}

func responseHandler(w http.ResponseWriter, r *http.Request) {
	totalRequests.Inc() // Increment total requests

	// Start measuring request duration
	timer := prometheus.NewTimer(requestDuration)
	defer timer.ObserveDuration()

	// Start OpenTelemetry span
	ctx, span := tracer.Start(r.Context(), "responseHandler")
	defer span.End()

	phrases, err := getMinionPhrases(ctx)
	var response map[string]interface{}
	if err != nil {
		log.Printf("Minion phrases fetch failed: %v", err)
		failedResponses.Inc() // Increment failed responses
		span.RecordError(err)
		span.SetAttributes(semconv.HTTPStatusCodeKey.Int(http.StatusInternalServerError))
		response = map[string]interface{}{
			"response_message": "Bello from ResponseService!",
		}
	} else {
		response = map[string]interface{}{
			"response_message": "Bello from ResponseService!",
			"minion_phrases":   phrases,
		}
		successfulResponses.Inc() // Increment successful responses
	}

	// Add instance ID to response if available
	if instanceID := os.Getenv("INSTANCE_ID"); instanceID != "" {
		response["response_message"] = fmt.Sprintf("Bello from ResponseService %s!", instanceID)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)

	// Add HTTP status code to the span
	span.SetAttributes(semconv.HTTPStatusCodeKey.Int(http.StatusOK))
}

func getMinionPhrases(ctx context.Context) ([]string, error) {
	// Use OpenTelemetry instrumentation for HTTP client
	client := http.Client{Transport: otelhttp.NewTransport(http.DefaultTransport)}
	req, _ := http.NewRequestWithContext(ctx, "GET", "http://consul.service.consul:8500/v1/kv/minion_phrases?raw", nil)
	resp, err := client.Do(req)
	if err != nil {
		log.Printf("Failed to fetch Minion phrases: %v", err)
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
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

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"status": "healthy"})
}

func main() {
	initTracer()

	http.Handle("/metrics", promhttp.Handler())

	http.HandleFunc("/response", responseHandler)

	http.HandleFunc("/health", healthHandler)

	fmt.Println("ResponseService running on port 6060...")
	log.Fatal(http.ListenAndServe(":6060", nil))
}
