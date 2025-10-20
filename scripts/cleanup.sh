#!/bin/bash

set -e

echo "🧹 SRE Showcase - Complete Cleanup"
echo "=================================="
echo ""
echo "⚠️  This will destroy ALL resources including:"
echo "   - Kubernetes deployments and services"
echo "   - Monitoring stack (Prometheus, Grafana, AlertManager)"
echo "   - EKS cluster and node groups"
echo "   - VPC and networking"
echo "   - Load balancers"
echo ""
echo "   Estimated time: ~10m"
echo ""
read -p "Type 'destroy' to confirm: " CONFIRM

if [ "$CONFIRM" != "destroy" ]; then
  echo "❌ Cleanup cancelled"
  exit 0
fi

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo ""
echo "Starting cleanup..."
echo ""

# Step 1: Delete Kubernetes applications
echo "1️⃣  Deleting application resources..."
kubectl delete -k "$PROJECT_ROOT/k8s/app/" --ignore-not-found=true

echo ""
echo "2️⃣  Deleting monitoring stack..."
kubectl delete -f "$PROJECT_ROOT/k8s/monitoring/alertmanager/alertmanager.yaml" --ignore-not-found=true
kubectl delete -f "$PROJECT_ROOT/k8s/monitoring/prometheus/alert-rules.yaml" --ignore-not-found=true
kubectl delete -f "$PROJECT_ROOT/k8s/monitoring/grafana.yaml" --ignore-not-found=true
kubectl delete -f "$PROJECT_ROOT/k8s/monitoring/prometheus.yaml" --ignore-not-found=true
kubectl delete namespace monitoring --ignore-not-found=true

echo ""
echo "   Waiting for load balancers to be deleted (30 seconds)..."
sleep 30

# Step 2: Destroy Terraform infrastructure
echo ""
echo "3️⃣  Destroying Terraform infrastructure..."
cd "$PROJECT_ROOT/terraform"
terraform destroy -auto-approve

# Step 3: Verify cleanup
echo ""
echo "4️⃣  Verifying cleanup..."
echo ""

CLUSTERS=$(aws eks list-clusters --region us-east-1 --query 'clusters[?contains(@, `sre-showcase`)]' --output text 2>/dev/null || echo "")
if [ -n "$CLUSTERS" ]; then
  echo "⚠️  Warning: EKS clusters still exist: $CLUSTERS"
else
  echo "✅ No EKS clusters found"
fi

VPCS=$(aws ec2 describe-vpcs --region us-east-1 --filters "Name=tag:Project,Values=sre-showcase" --query 'Vpcs[*].VpcId' --output text 2>/dev/null || echo "")
if [ -n "$VPCS" ]; then
  echo "⚠️  Warning: VPCs still exist: $VPCS"
else
  echo "✅ No VPCs found"
fi

LBS=$(aws elbv2 describe-load-balancers --region us-east-1 --query "LoadBalancers[?contains(LoadBalancerName, 'sre')].LoadBalancerArn" --output text 2>/dev/null || echo "")
if [ -n "$LBS" ]; then
  echo "⚠️  Warning: Load balancers still exist"
else
  echo "✅ No load balancers found"
fi

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "💰 Estimated cost saved: ~\$0.10-0.15 per hour"
echo ""
echo "To manually redeploy:"
echo "  1. cd terraform && terraform apply"
echo "  2.1 get the command to update kubeconfig: terraform output kubeconfig_command"
echo "  2.2 cd .. && aws eks update-kubeconfig --region us-east-1 --name sre-showcase-demo"
echo "  3. kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
echo "  4. kubectl apply -f k8s/monitoring/prometheus.yaml"
echo "  5. kubectl apply -f k8s/monitoring/grafana.yaml"
echo "  6. kubectl apply -f k8s/monitoring/prometheus/alert-rules.yaml"
echo "  7. kubectl apply -f k8s/monitoring/alertmanager/webhook-secret.yaml"
echo "  8. kubectl apply -f k8s/monitoring/alertmanager/alertmanager.yaml"
echo "  9. kubectl apply -k k8s/app/"
echo "  10. cd monitoring && ./setup-grafana.sh"
echo ""
echo "You can find a full script in deploy.sh"
