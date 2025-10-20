# GitHub Actions Setup

This project uses GitHub Actions for CI/CD. Follow these steps to enable automated workflows.

## Prerequisites

1. **AWS Account** with permissions to create EKS, VPC, EC2 resources
2. **GitHub Account** with this repository
3. **Slack Workspace** with webhook configured

---

## Step 1: Configure GitHub Secrets

Go to: **Repository → Settings → Secrets and variables → Actions → New repository secret**

Add these secrets:

### Required Secrets

| Secret Name | Description | How to Get |
|:------------|:------------|:-----------|
| `AWS_ACCESS_KEY_ID` | AWS access key | AWS Console → IAM → Users → Security credentials |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | Same as above |
| `SLACK_WEBHOOK_URL` | Slack webhook for alerts | <https://api.slack.com/apps> → Incoming Webhooks |

### Optional Secrets

| Secret Name | Description |
|:------------|:------------|
| `INFRACOST_API_KEY` | Cost estimation in PRs (optional) |

---

## Step 2: Make Container Registry Public

After the first CI run pushes an image:

1. Go to: <https://github.com/YOUR_USERNAME?tab=packages>
2. Click on `sre-app` package
3. Click **Package settings**
4. Scroll to **Danger Zone**
5. Click **Change visibility** → **Public**

This allows EKS to pull the image without authentication.

---

## Step 3: Enable GitHub Actions

1. Go to: **Repository → Actions**
2. Click **"I understand my workflows, go ahead and enable them"**

---

## Workflows Overview

### CI - Build and Test (`ci-build-test.yaml`)

**Triggers:** Push or PR to `main`

**What it does:**

1. Runs Python tests
2. Lints code with Ruff
3. Scans for vulnerabilities (Trivy)
4. Builds Docker image
5. Pushes to GitHub Container Registry

**Automatic:** ✅ Runs on every push

---

### CD - Deploy to EKS (`cd-deploy.yaml`)

**Triggers:** Manual only (`workflow_dispatch`)

**What it does:**

1. Connects to EKS cluster
2. Updates deployment with new image
3. Waits for rollout
4. Runs smoke tests
5. Sends Slack notification

**Manual:** ⚠️ Run via Actions tab → CD - Deploy to EKS → Run workflow

---

### Terraform - Plan (`terraform-plan.yaml`)

**Triggers:** PR with terraform changes

**What it does:**

1. Validates Terraform syntax
2. Runs `terraform plan`
3. Comments plan on PR
4. Runs security scans (tfsec, Checkov)

**Automatic:** ✅ Runs on PRs

---

### Cleanup (`cleanup.yaml`)

**Triggers:** Manual only (`workflow_dispatch`)

**What it does:**

1. Deletes Kubernetes resources
2. Runs `terraform destroy`
3. Verifies cleanup
4. Sends Slack notification

**Manual:** ⚠️ Requires typing "destroy" to confirm

---

## Typical Workflow

### Development Flow

1. Make code changes

1. Push to branch

1. CI runs automatically (build, test, push image)

1. Create PR

1. Review and merge

1. Manually trigger CD workflow to deploy

### Infrastructure Changes

1. Make Terraform changes

1. Push to branch

1. Create PR

1. Terraform Plan runs automatically

1. Review plan in PR comments

1. Merge PR

1. Manually run terraform apply locally or via CD

---

## Testing the Workflows

### Test CI Workflow

```bash
# Make a small change
echo "# Test" >> README.md
git add README.md
git commit -m "test: trigger CI"
git push origin main
```

Go to **Actions** tab and watch the workflow run.

---

**Test CD Workflow:**

1. Ensure infrastructure is deployed (⁠terraform apply)

1. Go to **Actions** → **CD - Deploy to EKS**

1. Click **Run workflow**

1. Select branch: ⁠`main`

1. Click **Run workflow**

---

## Troubleshooting

### "Error: No valid credential sources found"

**Solution:** Check AWS secrets are correctly set in repository settings.

### "Error: cluster not found"

**Solution:** Deploy infrastructure first with ⁠`terraform apply`.

### "Error: failed to push image"

**Solution:** Ensure you're logged into GHCR and package is public.

### Workflow not running

**Solution:** Check ⁠`.github/workflows/` files are in ⁠`main` branch.

---

## Security Notes

- ✅ Secrets are encrypted by GitHub

- ✅ Secrets are not exposed in logs

- ✅ Use least-privilege IAM policies

- ✅ Rotate AWS keys regularly

- ✅ Use separate AWS accounts for prod

---

## Disabling Workflows

To disable a workflow without deleting it:

1. Go to **Actions** → Select workflow

1. Click **⋯** (three dots)

1. Click **Disable workflow**
