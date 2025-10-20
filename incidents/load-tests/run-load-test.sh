#!/bin/bash

set -e

echo "📊 Running Sustained Load Test"
echo "=============================="
echo ""

APP_URL=$(kubectl get svc sre-app -n sre-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if [ -z "$APP_URL" ]; then
  echo "❌ Error: Could not get application URL"
  exit 1
fi

echo "📍 Application URL: http://$APP_URL"
echo "🚀 Starting sustained load test (50 users for 5 minutes)..."
echo ""

BASE_URL="http://$APP_URL" k6 run load-test.js

echo ""
echo "✅ Load test complete!"
