#!/bin/bash

echo "🐳 Building and testing Docker image"
echo "====================================="

# Build image
echo "📦 Building Docker image..."
docker build -t sre-showcase-app:local .

# Run container
echo ""
echo "🚀 Starting container..."
docker run -d -p 8000:8000 --name sre-test sre-showcase-app:local

# Wait for container to start
sleep 5

# Test endpoints
echo ""
echo "🔍 Testing containerized application..."

echo "Testing health endpoint..."
curl -s http://localhost:8000/health | jq .

echo ""
echo "Testing API endpoint..."
curl -s http://localhost:8000/api/data | jq .

# Check logs
echo ""
echo "📋 Container logs:"
docker logs sre-test

# Cleanup
echo ""
echo "🧹 Cleaning up..."
docker stop sre-test
docker rm sre-test

echo ""
echo "✅ Docker testing complete!"
