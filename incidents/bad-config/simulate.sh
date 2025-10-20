#!/bin/bash

set -e

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "🔥 Incident 3: Bad Configuration Change"
echo "========================================"
echo ""
echo "⚠️  This will:"
echo "   1. Set deployment replicas to 0"
echo "   2. Terminate all application pods"
echo "   3. Trigger alerts"
echo "   4. Make application unavailable"
echo ""
read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Cancelled"
  exit 0
fi

echo ""
echo "1️⃣  Applying broken configuration (replicas: 0)..."
kubectl apply -f "$SCRIPT_DIR/deployment-broken.yaml"

echo ""
echo "2️⃣  Watching pods terminate..."
echo ""

kubectl get pods -n sre-app -w &
WATCH_PID=$!
sleep 20
kill $WATCH_PID 2>/dev/null || true

echo ""
echo ""
echo "3️⃣  Incident in progress:"
echo ""
kubectl get deployment sre-app -n sre-app
echo ""
echo "   - All pods terminated"
echo "   - Application is DOWN"
echo "   - Check Prometheus alerts"
echo "   - Check Slack notifications"
echo ""

# Try to access application (will fail)
APP_URL=$(kubectl get svc sre-app -n sre-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Testing application (should fail):"
curl -m 5 "http://$APP_URL/health" 2>&1 || echo "❌ Application unreachable (expected)"

echo ""
echo ""
read -p "Press Enter to fix the configuration..."

echo ""
echo "4️⃣  Scaling deployment back to 2 replicas..."
kubectl scale deployment sre-app --replicas=2 -n sre-app

echo "5️⃣  Waiting for pods to be ready..."
kubectl rollout status deployment/sre-app -n sre-app

echo ""
echo "✅ Incident resolved!"
echo ""
echo "Final status:"
kubectl get deployment sre-app -n sre-app
kubectl get pods -n sre-app
echo ""

echo "Testing application health..."
sleep 5
curl -s "http://$APP_URL/health" | jq '.' || echo "Health check failed"

echo ""
echo "📊 Post-Incident Review:"
echo "   - Prometheus alerts should show PodsDown (resolved)"
echo "   - Slack should have alert + resolution messages"
echo "   - Grafana dashboard shows complete outage"
echo ""
echo "💡 Lessons Learned:"
echo "   - Configuration changes can cause complete outages"
echo "   - Always review replica counts before applying"
echo "   - Use GitOps with approval workflows in production"
echo "   - Consider policy enforcement (OPA/Kyverno)"