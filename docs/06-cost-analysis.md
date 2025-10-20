# Cost Analysis

Detailed cost breakdown and optimization strategies for the SRE Showcase project.

---

## Cost Overview

This project is designed to be **cost-effective** for demos and learning, with infrastructure that can be destroyed immediately after use.

---

## Cost Breakdown

### Per-Demo Estimated Cost (30 minutes)

| Resource | Hourly Rate | 30-Min Cost | Notes |
|:---------|:------------|:------------|:------|
| EKS Control Plane | $0.10 | $0.05 | Fixed cost per cluster |
| EC2 Spot (t3.small x2) | $0.0104 each | $0.0104 | 70% cheaper than on-demand |
| NAT Gateway | $0.045 | $0.0225 | Data processing extra |
| Application Load Balancer | $0.0225 | $0.0113 | Plus LCU charges |
| EBS Volumes (20GB x2) | $0.10/GB/month | ~$0.001 | Negligible for short runs |
| Data Transfer | Variable | ~$0.01 - $0.05 | Minimal for demos |
| **Total** | **~$0.20/hour** | **~$0.10 - $0.15** | **Per demo run** |

---

### Estimated Monthly Cost (If Running 24/7)

**⚠️ NOT RECOMMENDED - Always destroy after demos!**

| Resource | Monthly Cost | Notes |
|:---------|:-------------|:------|
| EKS Control Plane | $73.00 | $0.10/hour × 730 hours |
| EC2 Spot (t3.small x2) | ~$30.00 | ~$0.041/hour × 730 hours |
| NAT Gateway | $32.85 | $0.045/hour × 730 hours |
| Application Load Balancer | $16.43 | $0.0225/hour × 730 hours |
| Data Transfer | ~$10.00 | Estimated |
| **Total** | **~$162.28** | **If left running** |

---

## Cost Optimization Strategies

### 1. Spot Instances (Implemented)

**Savings:** 70% on compute costs

**Configuration:**

```hcl
# terraform/variables.tf
enable_spot_instances = true
```

**Trade-offs:**

- ✅ Massive cost savings
- ✅ Acceptable for demos
- ❌ Can be interrupted (rare)
- ❌ Not for production critical workloads

**Spot vs On-Demand:**

```bash
On-Demand t3.small: $0.0208/hour × 2 = $0.0416/hour
Spot t3.small:      $0.0104/hour × 2 = $0.0208/hour
Savings:            50% = $0.0208/hour
```

---

### 2. Right-Sized Instances (Implemented)

**Savings:** 50% vs t3.medium

**Configuration:**

```hcl
node_instance_types = ["t3.small"]
```

**Comparison:**

| Instance Type | vCPU | Memory | On-Demand | Spot |
|:--------------|:-----|:-------|:----------|:-----|
| t3.micro | 2 | 1 GB | $0.0104 | $0.0052 |
| t3.small | 2 | 2 GB | $0.0208 | $0.0104 |
| t3.medium | 2 | 4 GB | $0.0416 | $0.0208 |

**Why t3.small?**

- ✅ Sufficient for demo workload
- ✅ 2 GB RAM handles app + monitoring
- ✅ Half the cost of t3.medium
- ❌ May struggle under extreme load (acceptable for demos)

---

### 3. Single NAT Gateway (Implemented)

**Savings:** $32.85/month per additional NAT

**Configuration:**

```hcl
# terraform/modules/vpc/main.tf
single_nat_gateway = true
```

**Trade-offs:**

- ✅ 50% cost savings
- ✅ Sufficient for demos
- ❌ Single point of failure
- ❌ Not HA (acceptable for demos)

**Production Alternative:**

```hcl
# For production
single_nat_gateway = false  # NAT per AZ
```

---

### 4. Minimal Node Count (Implemented)

**Savings:** $15/month per node

**Configuration:**

```hcl
node_desired_size = 2
node_min_size     = 1
node_max_size     = 3
```

**Scaling Strategy:**

- Start with 2 nodes (HA)
- Scale to 3 under load (HPA)
- Scale down to 1 if needed (cost)

---

### 5. No Persistent Storage (Implemented)

**Savings:** $0.10/GB/month

**Configuration:**

```yaml
# All volumes use emptyDir
volumes:
  - name: storage
    emptyDir: {}
```

**Trade-offs:**

- ✅ No EBS costs
- ✅ Faster pod startup
- ❌ Data lost on pod restart
- ✅ Acceptable for stateless demos

---

### 6. Immediate Cleanup (Critical!)

**Savings:** Everything!

**Process:**

```bash
cd scripts
./cleanup.sh
# Type: destroy
```

**Verification:**

```bash
# Verify no resources remain
aws eks list-clusters --region us-east-1
aws ec2 describe-instances --region us-east-1 \
  --filters "Name=tag:Project,Values=sre-showcase" \
  --query 'Reservations[].Instances[?State.Name==`running`]'
```

**Set Calendar Reminders:**

- ⏰ After each demo
- ⏰ End of day
- ⏰ Weekly cleanup check

---

## Cost Monitoring

### AWS Cost Explorer

**Setup:**

1. Go to: AWS Console → Cost Explorer
2. Enable Cost Explorer (free)
3. Create cost report filtered by tag: `Project=sre-showcase`

**Recommended Alerts:**

```bash
Alert if daily cost > $5
Alert if monthly forecast > $50
```

---

### Terraform Cost Estimation

**Using Infracost (Optional):**

```bash
# Install
brew install infracost

# Register (free)
infracost register

# Generate cost estimate
cd terraform
infracost breakdown --path .
```

**Example Output:**

```bash
Name                                    Monthly Qty  Unit   Monthly Cost

aws_eks_cluster.main
 └─ EKS cluster                                 730  hours        $73.00

aws_eks_node_group.main
 └─ Linux/UNIX usage (spot, t3.small)         1,460  hours        $30.00

aws_nat_gateway.main
 ├─ NAT gateway                                 730  hours        $32.85
 └─ Data processed                              100  GB            $4.50

OVERALL TOTAL                                                    $162.28
```

---

## Hidden Costs to Watch

### 1. Orphaned Load Balancers

**Problem:** LoadBalancers created by Kubernetes services may not be deleted by Terraform

**Check:**

```bash
aws elbv2 describe-load-balancers --region us-east-1 \
  --query 'LoadBalancers[?contains(LoadBalancerName, `sre`)].LoadBalancerArn'
```

**Solution:**

```bash
# Delete manually if found
aws elbv2 delete-load-balancer --load-balancer-arn ARN
```

**Prevention:**

```bash
# Always delete K8s resources before Terraform
kubectl delete -k k8s/app/
kubectl delete -f k8s/monitoring/grafana.yaml
sleep 30  # Wait for LB deletion
terraform destroy
```

---

### 2. Elastic IPs

**Problem:** EIPs for NAT Gateway may not release

**Check:**

```bash
aws ec2 describe-addresses --region us-east-1 \
  --filters "Name=tag:Project,Values=sre-showcase"
```

**Solution:**

```bash
# Release if found
aws ec2 release-address --allocation-id ALLOCATION_ID
```

---

### 3. EBS Snapshots

**Problem:** Snapshots may be created automatically

**Check:**

```bash
aws ec2 describe-snapshots --region us-east-1 \
  --owner-ids self \
  --filters "Name=tag:Project,Values=sre-showcase"
```

**Solution:**

```bash
# Delete if found
aws ec2 delete-snapshot --snapshot-id SNAPSHOT_ID
```

---

### 4. CloudWatch Logs

**Problem:** EKS control plane logs accumulate

**Check:**

```bash
aws logs describe-log-groups --region us-east-1 \
  --log-group-name-prefix /aws/eks/sre-showcase
```

**Solution:**

```bash
# Delete log group
aws logs delete-log-group --log-group-name LOG_GROUP_NAME
```

---

## Cost Comparison

### This Project vs Alternatives

| Approach | 30-Min Cost | Monthly Cost | Notes |
|:---------|:------------|:-------------|:------|
| **This Project** | **$0.10** | **$162** | Optimized for demos |
| Managed K8s (GKE) | $0.12 | $180 | Similar to EKS |
| Managed K8s (AKS) | $0.08 | $140 | Slightly cheaper |
| Local (minikube) | $0.00 | $0.00 | No cloud costs, limited realism |
| ECS Fargate | $0.15 | $220 | More expensive, simpler |

---

## Budget Recommendations

### For Learning/Demos

**Monthly Budget:** $20-30

**Usage Pattern:**

- 2-3 demos per week
- 30 minutes each
- Immediate cleanup

**Actual Cost:**

```bash
3 demos/week × 4 weeks = 12 demos/month
12 demos × $0.10 = $1.20/month
Plus occasional mistakes: ~$5-10/month
Total: ~$6-11/month
```

---

### For Interview Preparation

**Monthly Budget:** $10-15

**Usage Pattern:**

- Practice 2x per week
- 1 hour each
- Immediate cleanup

**Actual Cost:**

```bash
2 sessions/week × 4 weeks = 8 sessions/month
8 sessions × 1 hour × $0.20 = $1.60/month
Plus setup/teardown time: ~$5/month
Total: ~$6-7/month
```

---

## Cost Optimization Checklist

### Before Deployment

- [ ] Confirm spot instances enabled
- [ ] Verify instance type is t3.small
- [ ] Check node count is minimal (2)
- [ ] Confirm single NAT gateway
- [ ] Set calendar reminder for cleanup

### During Demo

- [ ] Monitor AWS Cost Explorer
- [ ] Keep demo under 30 minutes
- [ ] Don't create unnecessary resources

### After Demo

- [ ] Run cleanup script immediately
- [ ] Verify all resources deleted
- [ ] Check for orphaned load balancers
- [ ] Release any elastic IPs
- [ ] Confirm $0 daily cost next day

---

## Emergency Cost Control

### If Costs Are High

**1. Immediate Actions:**

```bash
# Stop all running instances
aws ec2 stop-instances --instance-ids $(aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=sre-showcase" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].InstanceId' --output text)

# Delete cluster
aws eks delete-cluster --name sre-showcase-demo --region us-east-1
```

**2. Find Cost Culprits:**

```bash
# Check running instances
aws ec2 describe-instances --region us-east-1 \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,Tags[?Key==`Name`].Value|[0]]'

# Check load balancers
aws elbv2 describe-load-balancers --region us-east-1

# Check NAT gateways
aws ec2 describe-nat-gateways --region us-east-1 \
  --filter "Name=state,Values=available"
```

**3. Nuclear Option:**

```bash
cd scripts
./cleanup.sh
# Type: destroy
```

---

## Cost Savings Summary

| Optimization | Savings | Implementation |
|:-------------|:--------|:---------------|
| Spot Instances | 70% on compute | ✅ Implemented |
| Right-sized instances | 50% vs t3.medium | ✅ Implemented |
| Single NAT | 50% on NAT costs | ✅ Implemented |
| No persistent storage | 100% on EBS | ✅ Implemented |
| Immediate cleanup | 100% on idle time | ⚠️ Manual |
| **Total Savings** | **~85% vs typical setup** | |

---

## Talking Points

### Cost Awareness

> *"I designed this project with cost optimization in mind. By using spot instances, right-sized nodes, and immediate cleanup, I keep demo costs under $0.15 per run. In production, I'd balance cost with reliability - using on-demand for critical workloads and spot for batch jobs."*

### Cost vs Reliability Trade-offs

> *"For this demo, I prioritized cost over high availability - single NAT gateway, spot instances, minimal node count. In production, I'd use multi-AZ NAT gateways, a mix of on-demand and spot instances, and higher node counts. The key is understanding the trade-offs and making informed decisions based on requirements."*

### FinOps Practices

> *"I practice FinOps by tagging all resources, monitoring costs daily, and setting up budget alerts. I also use Terraform to ensure consistent, predictable infrastructure costs. In a team setting, I'd implement chargeback models and cost allocation tags to promote cost awareness across teams."*

---

## References

- [AWS EKS Pricing](https://aws.amazon.com/eks/pricing/)
- [AWS EC2 Pricing](https://aws.amazon.com/ec2/pricing/)
- [AWS EC2 Spot Instances](https://aws.amazon.com/ec2/spot/)
- [Infracost Documentation](https://www.infracost.io/docs/)
- [FinOps Foundation](https://www.finops.org/)
