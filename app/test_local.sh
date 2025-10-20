#!/bin/bash

echo "🧪 Testing SRE Showcase API locally"
echo "===================================="

# Set Python path
export PYTHONPATH="${PYTHONPATH}:$(pwd)"

# Install dependencies
echo "📦 Installing dependencies..."
pip install -r requirements.txt

# Run tests
echo ""
echo "🧪 Running unit tests..."
pytest tests/ -v

# Start the application in background
echo ""
echo "🚀 Starting application..."
uvicorn main:app --host 0.0.0.0 --port 8000 &
APP_PID=$!

# Wait for app to start
sleep 3

# Test endpoints
echo ""
echo "🔍 Testing endpoints..."

echo "Testing root endpoint..."
curl -s http://localhost:8000/ | jq .

echo ""
echo "Testing health endpoint..."
curl -s http://localhost:8000/health | jq .

echo ""
echo "Testing metrics endpoint..."
curl -s http://localhost:8000/metrics | head -n 20

echo ""
echo "Testing API data endpoint..."
curl -s http://localhost:8000/api/data | jq .

# Stop the application
echo ""
echo "🛑 Stopping application..."
kill $APP_PID

echo ""
echo "✅ Local testing complete!"
