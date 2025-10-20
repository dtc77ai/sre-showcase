# Setup Guide

Complete step-by-step guide for setting up the SRE Showcase project.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Infrastructure Deployment](#infrastructure-deployment)
4. [Application Deployment](#application-deployment)
5. [Monitoring Setup](#monitoring-setup)
6. [Verification](#verification)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools

| Tool | Version | Installation |
|:-----|:--------|:-------------|
| Terraform | >= 1.6.0 | `brew install terraform` |
| AWS CLI | >= 2.0 | `brew install awscli` |
| kubectl | >= 1.28 | `brew install kubectl` |
| Docker | >= 20.0 | `brew install --cask docker` |
| Python | >= 3.11 | `brew install python@3.11` |
| k6 | latest | `brew install k6` |
| jq | latest | `brew install jq` |

### Verify Installations

```bash
terraform --version
aws --version
kubectl version --client
docker --version
python3 --version
k6 version
jq --version
```

---

## Initial Setup

1. AWS Configuration

    ```bash
    # Configure AWS credentials
    aws configure

    # You'll be prompted for:
    # - AWS Access Key ID
    # - AWS Secret Access Key
    # - Default region (use: us-east-1)
    # - Default output format (use: json)

    # Verify configuration
    aws sts get-caller-identity
    ```

    **Expected output:**

    ```bash
    {
        "UserId": "AIDAXXXXXXXXXXXXXXXXX",
        "Account": "123456789012",
        "Arn": "arn:aws:iam::123456789012:user/your-username"
    }
    ```

1. GitHub Setup

    **Create Personal Access Token**

    1. Go to: <https://github.com/settings/tokens>
    1. Click "Generate new token (classic)"
    1. Select scopes:
        - `⁠write:packages`
        - ⁠`read:packages`
    1. Generate and copy the token

    **Login to GitHub Container Registry**

    ```bash
    echo YOUR_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin
    ```

1. Slack Setup

    **Create Workspace**

    1. Go to: <https://slack.com/create>
    1. Create a free workspace
    1. Create channel: `⁠#sre-alerts`

    **Create Webhook**

    1. Go to: <https://api.slack.com/apps>
    1. Click "Create New App" → "From scratch"
    1. Name: "SRE Showcase Alerts"
    1. Select your workspace
    1. Click "Incoming Webhooks"
    1. Activate Incoming Webhooks
    1. Click "Add New Webhook to Workspace"
    1. Select `⁠#sre-alerts` channel
    1. Copy the webhook URL

    **Webhook URL format:**

    ```bash
    https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX
    ```

1. Clone Repository

    ```bash
    git clone https://github.com/YOUR_USERNAME/sre-showcase.git
    cd sre-showcase
    ```

---

## Infrastructure Deployment

### Option A: Automated Deployment (Recommended)

```bash
cd scripts
./deploy.sh
```

Follow the prompts. The script will:

1. Build and push Docker image
1. Deploy infrastructure
1. Configure kubectl
1. Install metrics-server
1. Deploy monitoring
1. Deploy application
1. Setup Grafana

**Time:** ~20 minutes

### Option B: Manual Deployment

#### Step 1: Build Application Image

```bash
cd app

# Build for linux/amd64 (AWS EKS platform)
docker build --platform linux/amd64 \
  -t ghcr.io/YOUR_USERNAME/sre-showcase/sre-app:latest .

# Push to registry
docker push ghcr.io/YOUR_USERNAME/sre-showcase/sre-app:latest
```

#### Step 2: Make Image Public

1. Go to: <https://github.com/YOUR_USERNAME?tab=packages>
1. Click on `⁠sre-app` package
1. Click "Package settings"
1. Scroll to "Danger Zone"
1. Click "Change visibility" → "Public"
1. Confirm

#### Step 3: Configure Terraform

```bash
cd terraform

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit configuration
vim terraform.tfvars
```

**Required values:**

```bash
slack_webhook_url = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
github_repo       = "YOUR_USERNAME/sre-showcase"
```

**Optional values:**

```bash
aws_region          = "us-east-1"
project_name        = "sre-showcase"
environment         = "demo"
node_instance_types = ["t3.small"]
node_desired_size   = 2
```

#### Step 4: Deploy infrastructure

```bash
# Initialize Terraform
terraform init

# Review plan
terraform plan

# Apply (takes ~20 minutes)
terraform apply

# Save outputs
terraform output > ../outputs.txt
```

**What gets created:**

- VPC with public/private subnets
- NAT Gateway and Internet Gateway
- EKS cluster (control plane)
- EKS node group (2 t3.small spot instances)
- Security groups
- IAM roles and policies

#### Step 5: Configure kubectl

```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name sre-showcase-demo

# Verify connection
kubectl get nodes

# Expected output:
# NAME                         STATUS   ROLES    AGE   VERSION
# ip-10-0-x-x.ec2.internal    Ready    <none>   5m    v1.28.x
# ip-10-0-y-y.ec2.internal    Ready    <none>   5m    v1.28.x
```

#### Step 6: Install metrics server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Wait for it to be ready
kubectl wait --for=condition=Ready pod -l k8s-app=metrics-server -n kube-system --timeout=300s

# Verify
kubectl top nodes
```

---

## Application Deployment

### Step 1: Deploy Monitoring Stack

```bash
# Deploy Prometheus
kubectl apply -f k8s/monitoring/prometheus.yaml

# Wait for namespace to be ready
kubectl wait --for=condition=Ready namespace/monitoring --timeout=30s

# Deploy Grafana
kubectl apply -f k8s/monitoring/grafana.yaml

# Deploy alert rules
kubectl apply -f k8s/monitoring/prometheus/alert-rules.yaml

# Create webhook secret
cd k8s/monitoring/alertmanager
cp webhook-secret.yaml.example webhook-secret.yaml
vim webhook-secret.yaml  # Add your Slack webhook URL

# Deploy AlertManager
kubectl apply -f webhook-secret.yaml
kubectl apply -f alertmanager.yaml

# Verify all pods are running
kubectl get pods -n monitoring
```

**Expected pods:**

- prometheus-xxxxx (1/1 Running)
- grafana-xxxxx (1/1 Running)
- alertmanager-xxxxx (1/1 Running)

### Step 2: Deploy Application

```bash
# Deploy application
# Put the desired image value in a kustomization.yaml file, then apply
kubectl apply -k k8s/app/

# Wait for rollout
kubectl rollout status deployment/sre-app -n sre-app

# Verify pods
kubectl get pods -n sre-app
```

**Expected output:**

```bash
NAME                       READY   STATUS    RESTARTS   AGE
sre-app-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
sre-app-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
```

### Step 3: Setup Grafana Dashboard

```bash
cd monitoring
./setup-grafana.sh
```

---

## Monitoring Setup

### Access Grafana

```bash
# Get Grafana URL
kubectl get svc grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Or use port-forward
kubectl port-forward -n monitoring svc/grafana 3000:80
```

**Login:**

- URL: [http://GRAFANA_URL](http://grafana_url) or <http://localhost:3000>
- Username: ⁠`admin`
- Password: ⁠`admin`

### Verify Data Source

1. Go to: Connections → Data sources
1. You should see "Prometheus" (configured automatically)
1. Click "Prometheus" → "Save & test"
1. Should show: "Data source is working"

### Verify Dashboard

1. Go to: Dashboards
1. You should see "SRE Showcase - Application Dashboard"
1. Open it
1. All 6 panels should show data

---

## Verification

1. **Infrastructure Check**

    ```bash
    # Check EKS cluster
    aws eks describe-cluster --name sre-showcase-demo --region us-east-1

    # Check nodes
    kubectl get nodes

    # Check all pods
    kubectl get pods -A
    ```

1. **Application Check**

    ```bash
    # Get application URL
    APP_URL=$(kubectl get svc sre-app -n sre-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

    # Test endpoints
    curl http://$APP_URL/
    curl http://$APP_URL/health
    curl http://$APP_URL/api/data
    curl http://$APP_URL/metrics | head -20
    ```

1. **Monitoring Check**

    ```bash
    # Check Prometheus
    kubectl port-forward -n monitoring svc/prometheus 9090:9090 &
    curl -s http://localhost:9090/-/healthy
    # Should return: Prometheus is Healthy.

    # Check Grafana
    kubectl port-forward -n monitoring svc/grafana 3000:80 &
    curl -s http://localhost:3000/api/health
    # Should return: {"commit":"...","database":"ok",...}

    # Check AlertManager
    kubectl port-forward -n monitoring svc/alertmanager 9093:9093 &
    curl -s http://localhost:9093/-/healthy
    # Should return: OK
    ```

1. **Auto-scaling Check**

    ```bash
    # Check HPA
    kubectl get hpa -n sre-app

    # Should show:
    # NAME          REFERENCE            TARGETS         MINPODS   MAXPODS   REPLICAS
    # sre-app-hpa   Deployment/sre-app   2%/10%, 32%/80%   2         10        2

    # Check metrics
    kubectl top pods -n sre-app
    ```

1. **Run Quick Load Test**

    ```bash
    cd incidents/load-tests
    ./run-spike-test.sh
    ```

    **Watch for:**

    - ✅ k6 completes successfully
    - ✅ HPA scales pods (2 → 3-4)
    - ✅ Grafana shows spike in metrics
    - ✅ Pods scale back down after 5 minutes

---

## Troubleshooting

### Issue: Terraform Apply Fails

**Error:** `⁠Error creating IAM Role: EntityAlreadyExists`

**Solution:**

```bash
# Delete existing roles
aws iam delete-role --role-name sre-showcase-demo-cluster-role
aws iam delete-role --role-name sre-showcase-demo-node-group-role

# Retry
terraform apply
```

### Issue: kubectl Can't Connect

**Error:** `The connection to the server localhost:8080 was refused`

**Solution:**

```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name sre-showcase-demo

# Verify
kubectl cluster-info
```

### Issue: Pods Not Starting

**Error:** `ImagePullBackOff`

**Solution:**

```bash
# Check if image is public
# Go to: https://github.com/YOUR_USERNAME?tab=packages
# Make sure sre-app package is public

# Check image name in deployment
kubectl get deployment sre-app -n sre-app -o yaml | grep image:

# Should match: ghcr.io/YOUR_USERNAME/sre-showcase/sre-app:latest
```

### Issue: Grafana Shows No Data

**Error:** Dashboard panels show "No data"

**Solution:**

```bash
# Check Prometheus is scraping
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Open: http://localhost:9090/targets
# Verify sre-app pods are "UP"

# Generate some traffic
APP_URL=$(kubectl get svc sre-app -n sre-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
for i in {1..50}; do curl -s http://$APP_URL/api/data > /dev/null; sleep 1; done

# Refresh Grafana dashboard
```

### Issue: Alerts Not Firing

**Error:** No Slack notifications

**Solution:**

```bash
# Test webhook directly
curl -X POST YOUR_SLACK_WEBHOOK_URL \
  -H 'Content-Type: application/json' \
  -d '{"text":"Test from SRE Showcase"}'

# Check AlertManager config
kubectl get configmap alertmanager-config -n monitoring -o yaml

# Check AlertManager logs
kubectl logs -n monitoring deployment/alertmanager

# Restart AlertManager
kubectl rollout restart deployment/alertmanager -n monitoring
```

### Issue: High Costs

**Error:** AWS bill is higher than expected

**Solution:**

```bash
# Destroy resources immediately
cd scripts
./cleanup.sh

# Verify cleanup
aws eks list-clusters --region us-east-1
aws ec2 describe-instances --region us-east-1 --filters "Name=tag:Project,Values=sre-showcase"

# Check for orphaned load balancers
aws elbv2 describe-load-balancers --region us-east-1
```

---

## Next Steps

After successful setup:

1. ✅ Run through [TESTING.md](../TESTING.md) checklist
1. ✅ Practice incident scenarios
1. ✅ Review [Architecture](01-architecture.md)
1. ✅ Read [Troubleshooting Runbook](05-troubleshooting-runbook.md)
1. ✅ Prepare for demo presentation

---

## Getting Help

If you encounter issues not covered here:

1. Check [Troubleshooting Runbook](05-troubleshooting-runbook.md)
1. Review logs: ⁠`kubectl logs -n NAMESPACE POD_NAME`
1. Check events: `⁠kubectl get events -n NAMESPACE --sort-by='.lastTimestamp'`
1. Open an issue on GitHub

---

## Cleanup

When done with the demo (cleanup to avoid unnecessary AWS charges):

```bash
cd scripts
./cleanup.sh
# Type: destroy
```

**Time:** ~10 minutes
