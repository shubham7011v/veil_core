# Build stage
FROM golang:1.22-alpine AS builder

# Install build dependencies for cgo (required for modernc.org/sqlite or database/sql with sqlite)
RUN apk add --no-cache git gcc musl-dev

WORKDIR /app

# Copy go mod files first for better caching
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the binary with CGO enabled for SQLite
RUN CGO_ENABLED=1 GOOS=linux go build -o veil-server .

# Runtime stage
FROM alpine:latest

# Install runtime dependencies
RUN apk add --no-cache ca-certificates sqlite

WORKDIR /root/

# Copy binary from builder
COPY --from=builder /app/veil-server .

# Create data directory for SQLite persistence
RUN mkdir -p /root/data

# Set environment variables
ENV PORT=8080
ENV ENABLE_VOICE=false

# Expose port
EXPOSE 8080

# Define volume for database persistence
VOLUME ["/root/data"]

# Run
CMD ["./veil-server"]
