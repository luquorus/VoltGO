#!/bin/bash
# Script to run BookingService tests using Docker
# Prerequisites: PostgreSQL container must be running (from docker-compose)

set -e

echo "Running BookingService tests using Docker..."

# Check if PostgreSQL container is running
if ! docker ps | grep -q voltgo-postgres; then
    echo "Error: voltgo-postgres container is not running."
    echo "Please start it first: cd infra && docker-compose up -d postgres"
    exit 1
fi

# Get PostgreSQL container IP or use localhost
POSTGRES_HOST=${POSTGRES_HOST:-localhost}
POSTGRES_PORT=${POSTGRES_PORT:-5432}
POSTGRES_DB=${POSTGRES_DB:-voltgo}
POSTGRES_USER=${POSTGRES_USER:-voltgo_user}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-admin123}

echo "Connecting to PostgreSQL at $POSTGRES_HOST:$POSTGRES_PORT"

# Run tests in Docker container
docker run --rm \
    --network host \
    -v "$(pwd):/app" \
    -w /app \
    -e POSTGRES_HOST="$POSTGRES_HOST" \
    -e POSTGRES_PORT="$POSTGRES_PORT" \
    -e POSTGRES_DB="$POSTGRES_DB" \
    -e POSTGRES_USER="$POSTGRES_USER" \
    -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
    -e SPRING_PROFILES_ACTIVE=local \
    gradle:8.5-jdk17-alpine \
    sh -c "gradle test --tests 'com.example.evstation.booking.application.BookingServiceTest' --no-daemon"

echo "Tests completed!"

