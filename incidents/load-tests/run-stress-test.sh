#!/bin/bash

set -e

echo "💥 Running Stress Test"
echo "====================="
echo ""

APP_URL=$(kubectl get svc sre-app -n sre-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if [ -z "$APP_URL" ]; then
  echo "❌ Error: Could not get application URL"
  exit 1
fi

echo "📍 Application URL: http://$APP_URL"
echo "⚠️  This will push the system to its limits"
echo "🚀 Starting stress test (ramping up to 400 users)..."
echo ""

BASE_URL="http://$APP_URL" k6 run stress-test.js

echo ""
echo "✅ Stress test complete!"
echo ""
echo "📊 Review results to find:"
echo "   - Maximum sustainable load"
echo "   - Breaking point"
echo "   - Resource bottlenecks"
