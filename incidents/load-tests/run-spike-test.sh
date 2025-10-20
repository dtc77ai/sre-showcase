#!/bin/bash

set -e

echo "🔍 Getting application URL..."

# Get the load balancer URL
APP_URL=$(kubectl get svc sre-app -n sre-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if [ -z "$APP_URL" ]; then
  echo "❌ Error: Could not get application URL"
  echo "Make sure the service is deployed and has an external IP"
  exit 1
fi

echo "📍 Application URL: http://$APP_URL"
echo "🚀 Starting load test..."
echo ""

# Run k6 with the URL as an environment variable
BASE_URL="http://$APP_URL" k6 run spike-test.js

echo ""
echo "✅ Load test complete!"
