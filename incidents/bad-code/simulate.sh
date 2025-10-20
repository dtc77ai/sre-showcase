#!/bin/bash

set -e

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Configuration - Get GitHub username from env var or prompt
if [ -z "$GITHUB_USER" ]; then
  read -p "GitHub username: " GITHUB_USER
  export GITHUB_USER
fi

IMAGE_NAME="ghcr.io/$GITHUB_USER/sre-showcase/sre-app"

echo "🔥 Incident 2: Bad Code Deployment (Crash Loop)"
echo "==============================================="
echo ""
echo "Project root: $PROJECT_ROOT"
echo "GitHub user: $GITHUB_USER"
echo "Image: $IMAGE_NAME:broken"
echo ""
echo "⚠️  This will:"
echo "   1. Build and push a broken Docker image"
echo "   2. Deploy it to the cluster"
echo "   3. Cause pods to crash loop"
echo "   4. Trigger alerts"
echo ""
read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Cancelled"
  exit 0
fi

echo ""
echo "1️⃣  Backing up working code..."
cp "$PROJECT_ROOT/app/main.py" "$PROJECT_ROOT/app/main-working.py"

echo "2️⃣  Copying broken code..."
cp "$SCRIPT_DIR/main-broken.py" "$PROJECT_ROOT/app/main.py"

echo "3️⃣  Building broken image..."
cd "$PROJECT_ROOT/app"
docker build --platform linux/amd64 -t "$IMAGE_NAME:broken" .

echo "4️⃣  Pushing broken image..."
docker push "$IMAGE_NAME:broken"

echo "5️⃣  Restoring working code..."
cp "$PROJECT_ROOT/app/main-working.py" "$PROJECT_ROOT/app/main.py"
rm "$PROJECT_ROOT/app/main-working.py"

echo ""
echo "6️⃣  Deploying broken image to cluster..."
kubectl set image deployment/sre-app \
  sre-app="$IMAGE_NAME:broken" \
  -n sre-app

echo ""
echo "7️⃣  Monitoring the incident..."
echo ""
echo "   Watching pods (will show CrashLoopBackOff):"
echo ""

# Show pods for 30 seconds (macOS compatible)
kubectl get pods -n sre-app -w &
WATCH_PID=$!
sleep 30
kill $WATCH_PID 2>/dev/null || true

echo ""
echo ""
echo "8️⃣  Incident in progress:"
echo "   - Check Prometheus: kubectl port-forward -n monitoring svc/prometheus 9090:9090"
echo "   - Check Slack: #sre-alerts channel"
echo "   - Check pod logs: kubectl logs -n sre-app -l app=sre-app --tail=20"
echo ""
echo "Current pod status:"
kubectl get pods -n sre-app
echo ""

read -p "Press Enter to rollback and resolve the incident..."

echo ""
echo "9️⃣  Rolling back to previous version..."
kubectl rollout undo deployment/sre-app -n sre-app

echo "🔟 Waiting for rollback to complete..."
kubectl rollout status deployment/sre-app -n sre-app

echo ""
echo "✅ Incident resolved!"
echo ""
echo "Final pod status:"
kubectl get pods -n sre-app
echo ""

# Test application
APP_URL=$(kubectl get svc sre-app -n sre-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Testing application health..."
curl -s "http://$APP_URL/health" | jq '.' || echo "Health check failed"

echo ""
echo "📊 Post-Incident Review:"
echo "   - Prometheus alerts should show PodDown (resolved)"
echo "   - Slack should have alert + resolution messages"
echo "   - Grafana dashboard shows the incident timeline"
echo ""
echo "💡 Lessons Learned:"
echo "   - Deployment created new pod with broken code"
echo "   - Kubernetes kept old pods running (rolling update)"
echo "   - Health checks prevented broken pod from receiving traffic"
echo "   - Rollback restored service quickly"
