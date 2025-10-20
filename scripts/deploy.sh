#!/bin/bash

set -e

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🚀 SRE Showcase - Full Deployment"
echo "================================="
echo ""

# Check prerequisites
echo "Checking prerequisites..."
command -v terraform >/dev/null 2>&1 || { echo "❌ terraform not found"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl not found"; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "❌ aws cli not found"; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "❌ docker not found"; exit 1; }
echo "✅ All prerequisites found"
echo ""

# Step 1: Build and push Docker image
echo "1️⃣  Building and pushing Docker image..."

# Get GitHub username from env var or prompt
if [ -z "$GITHUB_USER" ]; then
  read -p "GitHub username: " GITHUB_USER
  export GITHUB_USER
fi

cd "$PROJECT_ROOT/app"
docker build --platform linux/amd64 -t "ghcr.io/$GITHUB_USER/sre-showcase/sre-app:latest" .
docker push "ghcr.io/$GITHUB_USER/sre-showcase/sre-app:latest"

# Step 2: Deploy infrastructure
echo ""
echo "2️⃣  Deploying infrastructure with Terraform..."
cd "$PROJECT_ROOT/terraform"

if [ ! -f "terraform.tfvars" ]; then
  echo "❌ terraform.tfvars not found"
  echo "   Copy terraform.tfvars.example and fill in your values"
  exit 1
fi

terraform init
terraform apply -auto-approve

# Step 3: Configure kubectl
echo ""
echo "3️⃣  Configuring kubectl..."
aws eks update-kubeconfig --region us-east-1 --name sre-showcase-demo

# Wait for nodes
echo "   Waiting for nodes to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Step 4: Install metrics-server
echo ""
echo "4️⃣  Installing metrics-server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Step 5: Deploy monitoring stack
echo ""
echo "5️⃣  Deploying monitoring stack..."
kubectl apply -f "$PROJECT_ROOT/k8s/monitoring/prometheus.yaml"
kubectl apply -f "$PROJECT_ROOT/k8s/monitoring/grafana.yaml"
kubectl apply -f "$PROJECT_ROOT/k8s/monitoring/prometheus/alert-rules.yaml"

# Check if webhook secret exists
if [ ! -f "$PROJECT_ROOT/k8s/monitoring/alertmanager/webhook-secret.yaml" ]; then
  echo "⚠️  Creating webhook secret from example..."
  cp "$PROJECT_ROOT/k8s/monitoring/alertmanager/webhook-secret.yaml.example" \
     "$PROJECT_ROOT/k8s/monitoring/alertmanager/webhook-secret.yaml"
  echo "   ⚠️  Edit k8s/monitoring/alertmanager/webhook-secret.yaml with your Slack webhook"
  read -p "   Press Enter after editing the webhook secret..."
fi

kubectl apply -f "$PROJECT_ROOT/k8s/monitoring/alertmanager/webhook-secret.yaml"
kubectl apply -f "$PROJECT_ROOT/k8s/monitoring/alertmanager/alertmanager.yaml"

sleep 10

# Step 6: Deploy application
echo ""
echo "6️⃣  Deploying application..."
kubectl apply -k "$PROJECT_ROOT/k8s/app/"

# Wait for app to be ready
echo "   Waiting for application to be ready..."
kubectl rollout status deployment/sre-app -n sre-app --timeout=300s

# Step 7: Setup Grafana
echo ""
echo "7️⃣  Setting up Grafana dashboard..."
cd "$PROJECT_ROOT/monitoring"
./setup-grafana.sh

# Step 8: Get URLs
echo ""
echo "✅ Deployment complete!"
echo ""
echo "📍 Service URLs:"
APP_URL=$(kubectl get svc sre-app -n sre-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
GRAFANA_URL=$(kubectl get svc grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "   Application: http://$APP_URL"
echo "   Grafana: http://$GRAFANA_URL (admin/admin)"
echo ""
echo "🧪 Test the application:"
echo "   curl http://$APP_URL/health"
echo ""
echo "📊 Run load tests:"
echo "   cd incidents/load-tests && ./run-spike-test.sh"
echo ""
echo "🔥 Simulate incidents:"
echo "   cd incidents/bad-code && ./simulate.sh"
echo "   cd incidents/bad-config && ./simulate.sh"
