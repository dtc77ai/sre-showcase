# Testing Checklist

Use this checklist to verify the complete SRE Showcase setup.

## Prerequisites Check

- [ ] AWS CLI configured (`aws sts get-caller-identity`)
- [ ] Docker installed and running
- [ ] kubectl installed
- [ ] terraform installed (>= 1.6.0)
- [ ] k6 installed
- [ ] Slack webhook created

---

## Deployment Test

### 1. Initial Deployment

```bash
cd scripts
./deploy.sh
```

**Verify:**

- [ ] Terraform creates ~30 resources

- [ ] EKS cluster is running

- [ ] 2 nodes are Ready

- [ ] All monitoring pods are Running

- [ ] 2 app pods are Running

- [ ] Grafana dashboard loads with data

- [ ] Application health endpoint responds

## Monitoring Test

### 2. Grafana Dashboard

```bash
# Get Grafana URL
kubectl get svc grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

**Verify:**

- [ ] Can login (admin/admin)

- [ ] Prometheus data source exists

- [ ] SRE App Dashboard exists

- [ ] All 5 panels show data

- [ ] Request Rate shows activity

- [ ] Active Pods shows 2

### 3. Prometheus Alerts

```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
```

Open <http://localhost:9090/alerts>

**Verify:**

- [ ] 3 alert rules configured (HighErrorRate, HighLatency, PodsDown)

- [ ] All alerts are green (inactive)

### 4. AlertManager

```bash
kubectl port-forward -n monitoring svc/alertmanager 9093:9093
```

Open <http://localhost:9093>

**Verify:**

- [ ] AlertManager UI loads

- [ ] Slack receiver configured

- [ ] No active alerts

## Application Test

### 5. Application Endpoints

```bash
APP_URL=$(kubectl get svc sre-app -n sre-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test endpoints

curl http://$APP_URL/

curl http://$APP_URL/health

curl http://$APP_URL/api/data

curl http://$APP_URL/metrics
```

**Verify:**

- [ ] All endpoints return `200`

- [ ] `/metrics` shows Prometheus format

- [ ] `/health` shows healthy status

## Load Testing

### 6. Spike Test (Auto-scaling)

```bash
cd incidents/load-tests

./run-spike-test.sh
```

**Watch in separate terminals:**

```bash
# Terminal 1: HPA

kubectl get hpa -n sre-app -w

# Terminal 2: Pods

kubectl get pods -n sre-app -w
```

**Verify:**

- [ ] k6 completes successfully

- [ ] HPA scales from 2 → >3 pods

- [ ] New pods become `Ready` and in `Running` state

- [ ] Grafana shows request spike

- [ ] Slack receives alert notification of `HighLatency`

- [ ] After 5 minutes, pods scale back to 2

### 7. Load Test

```bash
cd incidents/load-tests

./run-load-test.sh
```

**Verify:**

- [ ] k6 completes successfully

- [ ] HPA scales from 2 → >3 pods

- [ ] Sustained load for 5 minutes

- [ ] Error rate < 1%

- [ ] p95 latency < 500ms

- [ ] No pod restarts, no alerts fired

## Incident Scenarios

### 8. Incident 1: High Error Rate

```bash
# Generate errors

APP_URL=$(kubectl get svc sre-app -n sre-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

for i in {1..500}; do curl -s http://$APP_URL/api/flaky > /dev/null; sleep 0.3; done
```

**Verify:**

- [ ] Grafana Error Rate panel shows ~10%

- [ ] Prometheus alert fires (HighErrorRate)

- [ ] Slack receives alert notification

- [ ] After errors stop, alert resolves (~5 min)

- [ ] Slack receives resolution notification

### 9. Incident 2: Bad Code Deployment

```bash
cd incidents/bad-code

./simulate.sh
```

**Verify:**

- [ ] New pod enters `CrashLoopBackOff`

- [ ] Old pods remain healthy

- [ ] Prometheus alert fires (PodsDown, HealthCheckFailing)

- [ ] Slack receives alert

- [ ] Rollback succeeds

- [ ] All pods healthy

- [ ] Alert resolves

- [ ] Slack receives resolution

### 10. Incident 3: Bad Configuration Change

```bash
cd incidents/bad-config

./simulate.sh
```

**Verify:**

- [ ] All pods terminate (`0/0 Ready`)

- [ ] Application becomes unavailable

- [ ] Prometheus alert fires (PodsDown)

- [ ] Slack receives alert

- [ ] Scale back to 2 succeeds

- [ ] Pods become healthy

- [ ] Application recovers

- [ ] Slack receives resolution

## Cleanup Test

### 11. Complete Cleanup

```bash
cd scripts

./cleanup.sh

# Type: destroy
```

**Verify:**

- [ ] All Kubernetes resources deleted

- [ ] Terraform destroys successfully

- [ ] No EKS clusters remain

- [ ] No VPCs remain

- [ ] No load balancers remain

## GitHub Actions Test (Optional)

### 12. CI Workflow

```bash
# Make a change

echo "# Test" >> README.md

git add README.md

git commit -m "test: CI workflow"

git push origin main
```

**Verify:**

- [ ] Workflow runs automatically

- [ ] Tests pass

- [ ] Docker image builds

- [ ] Image pushed to GHCR

### 13. CD Workflow

Via GitHub UI: Actions → CD - Deploy to EKS → Run workflow

**Verify:**

- [ ] Workflow runs successfully

- [ ] Deployment updates

- [ ] Smoke tests pass

- [ ] Slack notification received

## Final Verification

- [ ] All tests passed

- [ ] No errors in any logs

- [ ] Documentation is clear

- [ ] All scripts are executable

- [ ] All secrets are in `.gitignore`

- [ ] Repository is ready for demo

## Demo Readiness

If all checkboxes are checked, the project is ready for:

- ✅ Team demonstrations

- ✅ Job interviews

- ✅ Portfolio showcase

- ✅ Learning/teaching SRE concepts
