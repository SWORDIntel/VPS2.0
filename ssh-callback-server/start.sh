#!/bin/bash
# POLYGOTTEM SSH Callback Server - Quick Start Script

set -e

echo "=========================================="
echo "POLYGOTTEM SSH Callback Server"
echo "=========================================="
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "[!] .env file not found. Creating from template..."
    cp .env.example .env

    # Generate API key
    API_KEY=$(openssl rand -base64 32)
    sed -i "s/your-secure-api-key-here-change-this/$API_KEY/" .env

    echo ""
    echo "=========================================="
    echo "GENERATED API KEY (SAVE THIS!):"
    echo "$API_KEY"
    echo "=========================================="
    echo ""
    echo "This key has been saved to .env"
    echo "Keep it secure!"
    echo ""
fi

# Check if data directory exists
if [ ! -d data ]; then
    echo "[*] Creating data directory..."
    mkdir -p data
fi

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "[!] Docker not found. Please install Docker first."
    echo "    Visit: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo "[!] Docker Compose not found. Please install Docker Compose first."
    echo "    Visit: https://docs.docker.com/compose/install/"
    exit 1
fi

# Build and start
echo "[*] Building and starting containers..."
docker-compose up -d --build

echo ""
echo "=========================================="
echo "✓ Callback Server Started Successfully!"
echo "=========================================="
echo ""
echo "Dashboard: http://$(hostname -I | awk '{print $1}'):5000/"
echo "           http://localhost:5000/"
echo ""
echo "API Key: $(grep API_KEY .env | cut -d= -f2)"
echo ""
echo "View logs: docker-compose logs -f"
echo "Stop server: docker-compose down"
echo ""
echo "=========================================="
