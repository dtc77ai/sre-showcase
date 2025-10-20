#!/bin/bash

set -e

echo "🎨 Setting up Grafana dashboard..."

# Check if kubectl is connected
if ! kubectl get nodes &> /dev/null; then
  echo "❌ Error: kubectl is not connected to a cluster"
  exit 1
fi

# Check if Grafana is running
if ! kubectl get svc grafana -n monitoring &> /dev/null; then
  echo "❌ Error: Grafana service not found in monitoring namespace"
  exit 1
fi

echo "📡 Port forwarding to Grafana..."
kubectl port-forward -n monitoring svc/grafana 3000:80 > /dev/null 2>&1 &
PF_PID=$!

# Wait for port forward to be ready
sleep 5

echo "📊 Importing SRE App dashboard..."
RESPONSE=$(curl -s -X POST http://admin:admin@localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @dashboards/sre-app-dashboard.json)

if echo "$RESPONSE" | jq -e '.status == "success"' > /dev/null 2>&1; then
  DASHBOARD_URL=$(echo "$RESPONSE" | jq -r '.url')
  echo "✅ Dashboard imported successfully!"
  
  GRAFANA_URL=$(kubectl get svc grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
  echo "📍 Dashboard URL: http://$GRAFANA_URL${DASHBOARD_URL}"
else
  echo "⚠️  Dashboard import response: $RESPONSE"
fi

echo "🧹 Cleaning up port forward..."
kill $PF_PID 2>/dev/null || true

echo ""
echo "✅ Grafana setup complete!"
echo ""
echo "To access Grafana:"
echo "  URL: http://$(kubectl get svc grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "  Login: admin / admin"
echo ""
echo "Note: Prometheus data source is automatically configured"
