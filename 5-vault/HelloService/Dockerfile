# Use an official Go image as a base image
FROM golang:1.20

# Set the working directory inside the container
WORKDIR /app

# Copy the source code to the working directory
COPY . .

# Build the Go program
RUN go build -o main main.go

# Expose the desired port (e.g., 8080)
EXPOSE 5000

# Run the executable
CMD ["./main"]
