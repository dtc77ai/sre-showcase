# SRE Showcase: Production-Ready Platform Engineering

> A comprehensive demonstration of Site Reliability Engineering practices, from infrastructure automation to incident response.

[![Terraform](https://img.shields.io/badge/Terraform-1.6+-purple?logo=terraform)](https://www.terraform.io/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28+-blue?logo=kubernetes)](https://kubernetes.io/)
[![AWS](https://img.shields.io/badge/AWS-EKS-orange?logo=amazon-aws)](https://aws.amazon.com/eks/)
[![Python](https://img.shields.io/badge/Python-3.11+-blue?logo=python)](https://www.python.org/)

## 🎯 Project Overview

This project showcases practical SRE skills through a real-world scenario: deploying, monitoring, and maintaining a production-grade application on AWS EKS. It demonstrates the complete lifecycle from infrastructure provisioning to incident response.

**Perfect for:**

- 🏢 Team demonstrations
- 💼 Job interviews (Platform/SRE/DevOps roles)
- 📚 Learning SRE best practices
- 🎓 Teaching infrastructure automation

### Key Objectives

- **Infrastructure as Code**: Fully automated AWS infrastructure with Terraform
- **CI/CD Pipeline**: Automated build, test, and deployment with GitHub Actions
- **Observability**: Comprehensive monitoring with Prometheus and Grafana
- **Incident Response**: Simulated incidents with documented resolution procedures
- **Cost Optimization**: Efficient resource usage with spot instances and auto-scaling

---

## 🛠️ Tech Stack

| Category | Technology |
|:---------|:-----------|
| **Infrastructure** | Terraform, AWS (VPC, EKS, ALB) |
| **Container Orchestration** | Kubernetes (optional: Helm) |
| **Application** | Python, FastAPI, Uvicorn |
| **CI/CD** | GitHub Actions, GitHub Container Registry |
| **Monitoring** | Prometheus, Grafana, AlertManager |
| **Load Testing** | k6 |
| **Alerting** | Slack Webhooks |

---

## 📊 SLO/SLI Definitions

### Service Level Indicators (SLIs)

- **Availability**: Percentage of successful requests (non-5xx responses)
- **Latency**: Request duration at p50, p95, and p99 percentiles
- **Error Rate**: Percentage of failed requests

### Service Level Objectives (SLOs)

- **Availability SLO**: 99.5% uptime over 30-day window

- **Latency SLO**:
  - p95 < 200ms
  - p99 < 500ms
- **Error Rate SLO**: < 1% of all requests

### Error Budget

- **Monthly Budget**: 0.5% downtime = ~3.6 hours
- **Budget Policy**: Documented in `docs/03-slo-sli-definitions.md`

---

## 💰 Cost Estimation

**Per 30-minute demo run**: ~$0.10 - $0.15

| Resource | Cost |
|:---------|:-----|
| EKS Control Plane | $0.05 |
| EC2 Spot Instances (t3.small x2) | $0.02 |
| Application Load Balancer | $0.01 |
| NAT Gateway | $0.02 |
| Data Transfer | $0.01 - $0.05 |
| **Total** | **~$0.10 - $0.15** |

**Cost optimization strategies:**

- ✅ Spot instances (70% savings)
- ✅ Minimal instance sizes (t3.small)
- ✅ Single NAT gateway
- ✅ Immediate cleanup after demos
- ✅ Auto-scaling based on demand

---

## 🚀 Quick Start (Manual Deployment)

### Prerequisites

Ensure you have the following tools installed:

```bash
# Check versions
terraform --version  # >= 1.6.0
aws --version        # >= 2.0
kubectl version      # >= 1.28
python3 --version    # >= 3.11
k6 version          # latest
docker --version    # >= 20.0

# Install missing tools (macOS)
brew install terraform awscli kubectl k6 jq docker
```

### AWS Setup

```bash
# Configure AWS credentials
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Default region: us-east-1
# Default output format: json

# Verify access
aws sts get-caller-identity
```

### Slack Setup

1. Create a Slack workspace (free): <https://slack.com/create>
2. Create channel `#sre-alerts`
3. Create Incoming Webhook:
    - Go to: <https://api.slack.com/apps>
    - Create New App → From scratch
    - Add "Incoming Webhooks" feature
    - Activate and create webhook for `#sre-alerts`
    - Copy webhook URL

---

## 📦 One-Command Deployment

```bash
# Clone repository
git clone https://github.com/yourusername/sre-showcase.git
cd sre-showcase

# Run deployment script
cd scripts
./deploy.sh
```

The script will:

1. ✅ Build and push Docker image

1. ✅ Deploy infrastructure with Terraform

1. ✅ Install metrics-server

1. ✅ Deploy monitoring stack

1. ✅ Deploy application

1. ✅ Configure Grafana dashboard

**Time:** ~20 minutes

---

## 🔧 **Manual Deployment (Step by Step)

1. Build and Push Docker Image

    ```bash
    cd app

    # Build image
    docker build --platform linux/amd64 -t ghcr.io/YOUR_USERNAME/sre-showcase/sre-app:latest .

    # Login to GHCR
    echo YOUR_GITHUB_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin

    # Push image
    docker push ghcr.io/YOUR_USERNAME/sre-showcase/sre-app:latest

    # Make package public
    # Go to: https://github.com/YOUR_USERNAME?tab=packages
    # Click sre-app → Package settings → Change visibility → Public
    ```

1. Configure Terraform

    ```bash
    cd terraform

    # Copy example configuration
    cp terraform.tfvars.example terraform.tfvars

    # Edit with your values
    vim terraform.tfvars
    ```

    **Required values:**

    ```bash
    slack_webhook_url = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
    github_repo       = "YOUR_USERNAME/sre-showcase"
    ```

1. Deploy Infrastructure

    ```bash
    # Initialize Terraform
    terraform init

    # Review plan
    terraform plan

    # Deploy (takes ~20 minutes)
    terraform apply -auto-approve

    # Configure kubectl
    aws eks update-kubeconfig --region us-east-1 --name sre-showcase-demo

    # Verify
    kubectl get nodes
    ```

1. Install Metrics Server

    ```bash
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    ```

1. Deploy Monitoring Stack

    ```bash
    # Create webhook secret
    cd k8s/monitoring/alertmanager
    cp webhook-secret.yaml.example webhook-secret.yaml
    vim webhook-secret.yaml  # Add your Slack webhook

    # Apply monitoring
    kubectl apply -f k8s/monitoring/prometheus.yaml
    kubectl apply -f k8s/monitoring/grafana.yaml
    kubectl apply -f k8s/monitoring/prometheus/alert-rules.yaml
    kubectl apply -f k8s/monitoring/alertmanager/webhook-secret.yaml
    kubectl apply -f k8s/monitoring/alertmanager/alertmanager.yaml
    ```

1. Deploy Application

    ```bash
    # Update kustomization.yaml with your GitHub username
    cd k8s/app
    
    # Edit the file and set your GitHub username
    # Update the newName field:
    # images:
    #   - name: ghcr.io/YOUR_USERNAME/YOUR_REPO/sre-app
    #     newName: ghcr.io/YOUR_USERNAME/sre-showcase/sre-app
    #     newTag: latest
    vim kustomization.yaml
    
    # Apply with kustomize
    cd ../..
    kubectl apply -k k8s/app/

    # Wait for ready
    kubectl rollout status deployment/sre-app -n sre-app
    ```

1. Setup Grafana

    ```bash
    cd monitoring
    ./setup-grafana.sh
    ```

1. Get Service URLs

    ```bash
    # Application
    kubectl get svc sre-app -n sre-app

    # Grafana
    kubectl get svc grafana -n monitoring
    ```

1. Test Application Endpoints

    ```bash
    # Get application URL
    APP_URL=$(kubectl get svc sre-app -n sre-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    
    # Test health endpoints
    curl http://$APP_URL/health
    curl http://$APP_URL/ready
    
    # Test API endpoints
    curl http://$APP_URL/
    curl http://$APP_URL/api/data
    curl http://$APP_URL/api/status
    
    # Test incident simulation endpoints
    curl http://$APP_URL/api/slow       # Intentionally slow (0.5-2s)
    curl http://$APP_URL/api/flaky      # Random 10% failure rate
    
    # Admin endpoints (for incident simulation)
    curl -X POST http://$APP_URL/admin/break  # Break health check
    curl -X POST http://$APP_URL/admin/fix    # Restore health check
    
    # View metrics
    curl http://$APP_URL/metrics
    
    # Interactive API docs
    open http://$APP_URL/docs
    ```

---

## 🎬 Demo Flow (30 minutes)

Perfect for presentations:

1. **Introduction (3 min)**

    - Project overview and goals
    - SLO/SLI definitions
    - Tech stack walkthrough

1. **Infrastructure (5 min)**

    ```bash
    # Show Terraform code
    cat terraform/main.tf

    # Show infrastructure
    aws eks describe-cluster --name sre-showcase-demo
    kubectl get nodes
    ```

1. **CI/CD Pipeline (4 min)**

    - Walk through `⁠.github/workflows/`
    - Show GitHub Actions runs
    - Demonstrate container registry

1. **Observability (5 min)**

    ```bash
    # Open Grafana dashboard
    # Show metrics, SLO tracking

    # Show Prometheus alerts
    kubectl port-forward -n monitoring svc/prometheus 9090:9090
    ```

1. **Incident Scenarios (10 min)**

    **Scenario A: Spike Load (Auto-scaling)**

    ```bash
    cd incidents/load-tests
    ./run-spike-test.sh

    # Watch auto-scaling
    kubectl get hpa -n sre-app -w
    ```

    **Scenario B: Bad Code Deployment**

    ```bash
    cd incidents/bad-code
    ./simulate.sh
    ```

    **Scenario C: Bad Configuration**

    ```bash
    cd incidents/bad-config
    ./simulate.sh
    ```

1. **Documentation (3min)**

    - Show runbooks
    - Explain troubleshooting process
    - Discuss cost optimization

---

## 🔄 CI/CD with GitHub Actions (Optional)

This project includes GitHub Actions workflows for automated CI/CD.

### **Quick Setup**

1. **Configure secrets** in your GitHub repository:
    - `AWS_ACCESS_KEY_ID`
    - `⁠AWS_SECRET_ACCESS_KEY`
    - `⁠SLACK_WEBHOOK_URL`
1. **Enable workflows** in the Actions tab
1. **Make image public** after first build

📖 **Detailed instructions:** See <.github/SETUP.md>

### **Available Workflows**

| Workflow | Trigger | Purpose |
|:---------|:--------|:--------|
| **CI - Build and Test** | Automatic (push/PR) | Build, test, push Docker image |
| **CD - Deploy to EKS** | Manual | Deploy to Kubernetes cluster |
| **Terraform - Plan** | Automatic (PR) | Validate infrastructure changes |
| **Cleanup** | Manual | Destroy all resources |

---

## 🏗️ **Architecture Decisions**

### **Infrastructure vs Application Separation**

This project demonstrates a key SRE principle: **separation of concerns**.

**Infrastructure (Terraform):**

- VPC, EKS cluster, networking
- Changes infrequently (weeks/months)
- Managed by Platform/SRE team

**Application (Kubernetes YAML):**

- App deployments, services, scaling
- Changes frequently (multiple times per day)
- Managed by Development team

**Why not everything in Terraform?**

**Current Approach:**

- ✅ Fast application iterations
- ✅ No Terraform state conflicts
- ✅ Standard kubectl workflows
- ❌ No centralized state for apps

**Production Approach (GitOps):**

In production, add **ArgoCD** or **Flux**:

- ✅ Git as single source of truth
- ✅ Automatic drift detection
- ✅ Pull request workflow
- ✅ Audit trail and rollbacks

### **Talking Point**

> *"I separated application deployment from infrastructure because in real-world scenarios, applications change frequently while infrastructure is more stable. For this demo, I use manual kubectl apply for simplicity and transparency. In production, I would implement GitOps with ArgoCD to maintain a single source of truth in Git, enable PR-based workflows, and provide automatic drift detection."*

---

## 🧹 Cleanup

> [!IMPORTANT]
> Destroy resources after demo to avoid charges!

```bash
cd scripts
./cleanup.sh
# Type: destroy
```

**Time:** ~10 minutes

**Verify cleanup:**

```bash
aws eks list-clusters --region us-east-1
aws ec2 describe-vpcs --region us-east-1 --filters "Name=tag:Project,Values=sre-showcase"
```

---

## 📚 Documentation

Comprehensive documentation available in `⁠docs/`:

- [Architecture Overview](docs/01-architecture.md) - System design and components
- [Setup Guide](docs/02-setup-guide.md) - Detailed installation instructions
- [SLO/SLI Definitions](docs/03-slo-sli-definitions.md) - Service level objectives
- [Incident Scenarios](docs/04-incident-scenarios.md) - Simulated incidents and responses
- [Troubleshooting Runbook](docs/05-troubleshooting-runbook.md) - Common issues and solutions
- [Cost Analysis](docs/06-cost-analysis.md) - Cost breakdown and optimization
- [Environment Management](docs/07-environment-management.md) - Multi-environment strategies

**Testing:** See <TESTING.md> for complete test checklist

**GitHub Actions:** See <.github/SETUP.md> for CI/CD setup

---

## 🎓 Learning Outcomes

By exploring this project, you'll understand:

- ✅ Infrastructure as Code with Terraform modules
- ✅ Kubernetes deployment patterns and best practices
- ✅ CI/CD pipeline design and implementation
- ✅ Observability stack setup and configuration
- ✅ SLO/SLI definition and tracking
- ✅ Incident response and troubleshooting
- ✅ Cost optimization strategies
- ✅ Security best practices

---

## 🔮 Future Enhancements

Potential additions (not implemented):

- **GitOps**: ArgoCD for declarative deployments
- **Service Mesh**: Istio/Linkerd for advanced traffic management
- **Chaos Engineering**: Chaos Mesh for resilience testing
- **Multi-region**: Cross-region failover
- **Backup/DR**: Velero for disaster recovery
- **Security Scanning**: Trivy, Falco, OPA
- **Log Aggregation**: ELK/Loki stack

---

## 📝 License

MIT License - feel free to use this project for learning and portfolio purposes.

---

## 🤝 Contributing

This is a personal showcase project, but suggestions are welcome! Open an issue or PR.
