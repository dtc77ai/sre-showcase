# Environment Management

Strategies for managing multiple environments with Terraform workspaces.

---

## Overview

This project uses **Terraform workspaces** for environment separation, allowing you to manage dev, staging, and production environments from a single codebase.

---

## Current Setup

### Default Configuration

The project is configured for a single "demo" environment by default:

- **Workspace**: `default`
- **Environment**: `demo`
- **Purpose**: Demonstrations and learning
- **Lifecycle**: Ephemeral (create and destroy frequently)

---

## Terraform Workspaces

### What Are Workspaces?

Terraform workspaces allow you to manage multiple instances of infrastructure from the same configuration.

**Key Concepts:**

- Each workspace has its own state file
- Same code, different state
- Useful for dev/staging/prod separation

### Available Workspaces

```bash
# List workspaces
terraform workspace list

# Current workspace (marked with *)
# * default
```

---

## Multi-Environment Setup

### Creating Environments

```bash
# Create workspaces
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# List all workspaces
terraform workspace list
# Output:
#   default
#   dev
#   staging
# * prod
```

### Switching Environments

```bash
# Switch to dev
terraform workspace select dev

# Verify current workspace
terraform workspace show
# Output: dev

# Deploy to dev
terraform apply
```

---

## Environment-Specific Configuration

### Using Locals for Environment Config

The project uses `locals` in `terraform/variables.tf` to define environment-specific settings:

```hcl
locals {
  # Use workspace name as environment
  environment = terraform.workspace == "default" ? var.environment : terraform.workspace

  # Environment-specific node configurations
  node_config = {
    demo = {
      desired_size     = 2
      min_size         = 1
      max_size         = 3
      instance_types   = ["t3.small"]
      use_spot         = true
    }
    dev = {
      desired_size     = 2
      min_size         = 1
      max_size         = 4
      instance_types   = ["t3.small"]
      use_spot         = true
    }
    staging = {
      desired_size     = 2
      min_size         = 2
      max_size         = 5
      instance_types   = ["t3.medium"]
      use_spot         = true
    }
    prod = {
      desired_size     = 3
      min_size         = 3
      max_size         = 10
      instance_types   = ["t3.medium"]
      use_spot         = false  # On-demand for stability
    }
  }

  # Select configuration based on environment
  selected_node_config = local.node_config[local.environment]
}
```

### Using Environment Config

In `terraform/modules/eks/main.tf`:

```hcl
resource "aws_eks_node_group" "main" {
  # ...
  
  capacity_type  = var.enable_spot_instances ? "SPOT" : "ON_DEMAND"
  instance_types = var.node_instance_types
  
  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }
  
  # ...
}
```

---

## Deployment Workflow

### Deploy to Dev

```bash
# Switch to dev workspace
terraform workspace select dev

# Review plan
terraform plan

# Apply
terraform apply

# Cluster name will be: sre-showcase-dev
```

### Deploy to Staging

```bash
# Switch to staging workspace
terraform workspace select staging

# Apply
terraform apply

# Cluster name will be: sre-showcase-staging
```

### Deploy to Production

```bash
# Switch to prod workspace
terraform workspace select prod

# Review carefully!
terraform plan

# Apply with approval
terraform apply

# Cluster name will be: sre-showcase-prod
```

---

## State Management

### Local State (Current)

**Location:** `terraform/terraform.tfstate.d/`

**Structure:**

```bash
terraform/
├── terraform.tfstate          # default workspace
└── terraform.tfstate.d/
    ├── dev/
    │   └── terraform.tfstate
    ├── staging/
    │   └── terraform.tfstate
    └── prod/
        └── terraform.tfstate
```

**Pros:**

- ✅ Simple setup
- ✅ No additional AWS resources
- ✅ No cost

**Cons:**

- ❌ Not suitable for teams
- ❌ No state locking
- ❌ State stored locally
- ❌ Risk of state loss

---

### Remote State (Production Pattern)

For team collaboration, use **S3 backend with DynamoDB locking**.

#### Setup S3 Backend

**1. Create S3 bucket and DynamoDB table:**

```bash
# Create S3 bucket for state
aws s3 mb s3://sre-showcase-terraform-state --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket sre-showcase-terraform-state \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket sre-showcase-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Create DynamoDB table for locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

**2. Create `terraform/backend.tf`:**

```hcl
terraform {
  backend "s3" {
    bucket         = "sre-showcase-terraform-state"
    key            = "env/${terraform.workspace}/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

**3. Initialize backend:**

```bash
# Migrate from local to remote state
terraform init -migrate-state
```

**Benefits:**

- ✅ Team collaboration
- ✅ State locking (prevents conflicts)
- ✅ State versioning (rollback capability)
- ✅ Encryption at rest
- ✅ Centralized state management

**Cost:**

- S3: ~$0.023/GB/month (negligible)
- DynamoDB: Pay-per-request (negligible)
- **Total: < $1/month**

---

## Kubernetes Namespaces

Even within a single Terraform environment, use **Kubernetes namespaces** for logical separation.

### Current Namespaces

```yaml
# Application namespace
apiVersion: v1
kind: Namespace
metadata:
  name: sre-app
  labels:
    environment: demo
---
# Monitoring namespace
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    environment: demo
```

### Environment-Specific Namespaces

For multi-environment setups:

```yaml
# Dev environment
apiVersion: v1
kind: Namespace
metadata:
  name: sre-app-dev
  labels:
    environment: dev
---
# Staging environment
apiVersion: v1
kind: Namespace
metadata:
  name: sre-app-staging
  labels:
    environment: staging
```

---

## Environment Comparison

### Configuration Differences

| Setting | Demo | Dev | Staging | Prod |
|:--------|:-----|:----|:--------|:-----|
| **Nodes** | 2 | 2 | 2 | 3 |
| **Instance Type** | t3.small | t3.small | t3.medium | t3.medium |
| **Spot Instances** | ✅ Yes | ✅ Yes | ✅ Yes | ❌ No |
| **Max Pods** | 3 | 4 | 5 | 10 |
| **NAT Gateway** | Single | Single | Single | Multi-AZ |
| **Monitoring** | Basic | Basic | Full | Full |
| **Backup** | None | None | Daily | Hourly |

---

## Best Practices

### For This Project (Demo/Showcase)

**Current Approach:**

- ✅ Single workspace (`default`)
- ✅ Local state
- ✅ Simple and understandable
- ✅ Cost-effective
- ✅ Easy to destroy and recreate

**Rationale:**

This is a **learning/demo project**, not a production system. Simplicity and cost are prioritized over enterprise features.

---

### For Production Projects

**Recommended Approach:**

1. **Separate AWS Accounts per Environment**

   ```bash
   AWS Organization
   ├── dev-account (123456789012)
   ├── staging-account (234567890123)
   └── prod-account (345678901234)
   ```

2. **Remote State with S3 + DynamoDB**

   - State locking enabled
   - Versioning enabled
   - Encryption enabled

3. **Separate Terraform Directories**

   ```bash
   terraform/
   └── environments/
       ├── dev/
       │   ├── main.tf
       │   └── terraform.tfvars
       ├── staging/
       │   └── ...
       └── prod/
           └── ...
   ```

4. **CI/CD for Terraform**

   - Automated `terraform plan` on PRs
   - Manual approval for `terraform apply`
   - Separate pipelines per environment

5. **State Access Control**

   - IAM policies for state bucket
   - Least privilege access
   - Audit logging enabled

---

## Alternative Patterns

### Pattern 1: Separate Directories

**Structure:**

```bash
terraform/
└── environments/
    ├── dev/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── terraform.tfvars
    ├── staging/
    │   └── ...
    └── prod/
        └── ...
```

**Pros:**

- ✅ Complete isolation
- ✅ Different backends per environment
- ✅ Can have different module versions
- ✅ Safest for production

**Cons:**

- ❌ Code duplication
- ❌ More complex structure
- ❌ Harder to maintain consistency

---

### Pattern 2: Terragrunt

**Structure:**

```bash
infrastructure/
├── terragrunt.hcl
├── modules/
│   └── eks/
└── environments/
    ├── dev/
    │   └── terragrunt.hcl
    ├── staging/
    │   └── terragrunt.hcl
    └── prod/
        └── terragrunt.hcl
```

**Pros:**

- ✅ DRY (Don't Repeat Yourself)
- ✅ Manages remote state automatically
- ✅ Dependency management
- ✅ Best for large organizations

**Cons:**

- ❌ Additional tool to learn
- ❌ More complexity
- ❌ Overkill for small projects

---

### Pattern 3: Workspaces (Current)

**Structure:**

```bash
terraform/
├── main.tf
├── variables.tf
└── modules/
```

**Pros:**

- ✅ Simple and clean
- ✅ Single codebase
- ✅ Easy to understand
- ✅ Good for demos/learning

**Cons:**

- ❌ Easy to apply to wrong workspace
- ❌ Shared backend configuration
- ❌ Less isolation

---

## Switching Strategies

### From Workspaces to Separate Directories

If you outgrow workspaces:

```bash
# 1. Export current state
terraform workspace select dev
terraform state pull > dev-state.json

# 2. Create new directory structure
mkdir -p environments/dev
cp main.tf variables.tf environments/dev/

# 3. Import state
cd environments/dev
terraform init
terraform state push ../../dev-state.json

# 4. Verify
terraform plan
```

---

## Environment Variables

### Using Environment Variables

For sensitive values, use environment variables instead of `terraform.tfvars`:

```bash
# Set environment variables
export TF_VAR_slack_webhook_url="https://hooks.slack.com/..."
export TF_VAR_github_repo="username/sre-showcase"

# Apply without tfvars file
terraform apply
```

### Environment-Specific Variables

```bash
# Dev environment
export TF_VAR_environment="dev"
export TF_VAR_node_desired_size=2

# Prod environment
export TF_VAR_environment="prod"
export TF_VAR_node_desired_size=3
```

---

## Cleanup Per Environment

### Destroy Specific Environment

```bash
# Switch to environment
terraform workspace select dev

# Destroy
terraform destroy

# Verify
aws eks list-clusters --region us-east-1
```

### Destroy All Environments

```bash
# Destroy each workspace
for env in dev staging prod; do
  terraform workspace select $env
  terraform destroy -auto-approve
done

# Switch back to default
terraform workspace select default
terraform destroy -auto-approve
```

---

## Talking Points

### Why Workspaces?

> *"I chose Terraform workspaces for this demo because they provide a simple way to show environment separation without the complexity of separate directories. In production, I'd evaluate based on team size and requirements - workspaces for small teams, separate directories for larger organizations, or Terragrunt for complex multi-account setups."*

### Environment Strategy

> *"My environment strategy balances isolation with maintainability. For this project, I use workspaces with environment-specific locals. In production, I'd use separate AWS accounts per environment, remote state with locking, and CI/CD pipelines with approval gates for production changes."*

### Terraform State Management

> *"I'm using local state for this demo to keep it simple, but I understand the importance of remote state in team environments. In production, I'd use S3 with DynamoDB locking, enable versioning for rollback capability, and implement strict IAM policies for state access."*

---

## References

- [Terraform Workspaces](https://www.terraform.io/docs/language/state/workspaces.html)
- [Terraform Backend Configuration](https://www.terraform.io/docs/language/settings/backends/s3.html)
- [Terragrunt](https://terragrunt.gruntwork.io/)
- [AWS Multi-Account Strategy](https://aws.amazon.com/organizations/getting-started/best-practices/)
