# Troubleshooting Runbook

Common issues and their solutions for the SRE Showcase project.

---

## Table of Contents

1. [Quick Diagnostics](#quick-diagnostics)
2. [Infrastructure Issues](#infrastructure-issues)
3. [Application Issues](#application-issues)
4. [Monitoring Issues](#monitoring-issues)
5. [Networking Issues](#networking-issues)
6. [Performance Issues](#performance-issues)
7. [Useful Commands](#useful-commands)

---

## Quick Diagnostics

### Health Check Commands

```bash
# Check all resources
kubectl get all -A

# Check node health
kubectl get nodes
kubectl top nodes

# Check pod health
kubectl get pods -A
kubectl top pods -A

# Check recent events
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

# Check cluster info
kubectl cluster-info
```

---

## Infrastructure Issues

### Issue: Terraform Apply Fails

**Symptom:**

```bash
Error: creating IAM Role: EntityAlreadyExists
```

**Diagnosis:**

```bash
# Check if roles exist
aws iam get-role --role-name sre-showcase-demo-cluster-role
aws iam get-role --role-name sre-showcase-demo-node-group-role
```

**Solution:**

```bash
# List and detach policies
aws iam list-attached-role-policies --role-name sre-showcase-demo-cluster-role
aws iam detach-role-policy --role-name sre-showcase-demo-cluster-role --policy-arn POLICY_ARN

# Delete roles
aws iam delete-role --role-name sre-showcase-demo-cluster-role
aws iam delete-role --role-name sre-showcase-demo-node-group-role

# Retry terraform
terraform apply
```

### Issue: EKS Cluster Not Accessible

**Symptom:**

```bash
error: You must be logged in to the server (Unauthorized)
```

**Diagnosis:**

```bash
# Check AWS credentials
aws sts get-caller-identity

# Check kubeconfig
cat ~/.kube/config | grep sre-showcase
```

**Solution:**

```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name sre-showcase-demo

# Verify
kubectl get nodes
```

### Issue: Nodes Not Ready

**Symptom:**

```bash
NAME                         STATUS     ROLES    AGE
ip-10-0-x-x.ec2.internal    NotReady   <none>   5m
```

**Diagnosis:**

```bash
# Describe node
kubectl describe node NODE_NAME

# Check node logs (if accessible)
kubectl get events --field-selector involvedObject.name=NODE_NAME
```

**Solution:**

```bash
# Wait for node to initialize (can take 5-10 minutes)
kubectl wait --for=condition=Ready nodes --all --timeout=600s

# If still not ready, check EKS console for errors
aws eks describe-nodegroup --cluster-name sre-showcase-demo --nodegroup-name sre-showcase-demo-node-group
```

---

## Application Issues

### Issue: Pods in CrashLoopBackOff

**Symptom:**

```bash
NAME                       READY   STATUS             RESTARTS
sre-app-xxxxxxxxxx-xxxxx   0/1     CrashLoopBackOff   5
```

**Diagnosis:**

```bash
# Check pod logs
kubectl logs -n sre-app POD_NAME

# Check previous logs (if restarted)
kubectl logs -n sre-app POD_NAME --previous

# Describe pod
kubectl describe pod -n sre-app POD_NAME
```

**Common Causes & Solutions:**

1. Image Pull Error

    ```bash
    # Check image name
    kubectl get deployment sre-app -n sre-app -o yaml | grep image:

    # Verify image exists and is public
    docker pull ghcr.io/USERNAME/sre-showcase/sre-app:latest
    ```

1. Application Crash

    ```bash
    # Check logs for errors
    kubectl logs -n sre-app POD_NAME | grep -i error

    # Rollback to previous version
    kubectl rollout undo deployment/sre-app -n sre-app
    ```

1. Resource Limits

    ```bash
    # Check resource usage
    kubectl top pod -n sre-app POD_NAME

    # Increase limits if needed
    kubectl edit deployment sre-app -n sre-app
    ```

### Issue: Pods Pending

**Symptom:**

```bash
NAME                       READY   STATUS    RESTARTS
sre-app-xxxxxxxxxx-xxxxx   0/1     Pending   0
```

**Diagnosis:**

```bash
# Describe pod to see reason
kubectl describe pod -n sre-app POD_NAME

# Check node capacity
kubectl describe nodes | grep -A 5 "Allocated resources"
```

**Common Causes & Solutions:**

1. Insufficient Resources

    ```bash
    # Check node capacity
    kubectl top nodes

    # Scale up nodes or reduce pod requests
    kubectl scale deployment sre-app --replicas=1 -n sre-app
    ```

1. Node Selector Mismatch

    ```bash
    # Check node labels
    kubectl get nodes --show-labels

    # Remove node selector if present
    kubectl edit deployment sre-app -n sre-app
    ```

### Issue: Service Unavailable (503)

**Symptom:**

```bash
curl http://APP_URL/health
# Returns: 503 Service Unavailable
```

**Diagnosis:**

```bash
# Check pod status
kubectl get pods -n sre-app

# Check service endpoints
kubectl get endpoints sre-app -n sre-app

# Check pod readiness
kubectl describe pod -n sre-app POD_NAME | grep -A 10 "Readiness"
```

**Solution:**

```bash
# If no pods are ready, check logs
kubectl logs -n sre-app -l app=sre-app

# If readiness probe failing, check endpoint
kubectl exec -n sre-app POD_NAME -- curl localhost:8000/ready

# Temporarily disable readiness probe for debugging
kubectl edit deployment sre-app -n sre-app
# Comment out readinessProbe section
```

---

## Monitoring Issues

### Issue: Grafana Shows No Data

**Symptom:**

Dashboard panels show "No data"

**Diagnosis:**

```bash
# Check Prometheus is running
kubectl get pods -n monitoring -l app=prometheus

# Check if Prometheus is scraping
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Open: http://localhost:9090/targets
```

**Solution:**

1. Prometheus Not Scraping

    ```bash
    # Verify service annotations exist
    kubectl get svc sre-app -n sre-app -o yaml | grep prometheus

    # Should have (these are already in k8s/app/deployment.yaml):
    # prometheus.io/scrape: "true"
    # prometheus.io/port: "8000"
    # prometheus.io/path: "/metrics"

    # If missing (shouldn't be if deployed correctly), add them:
    kubectl annotate svc sre-app -n sre-app \
    prometheus.io/scrape=true \
    prometheus.io/port=8000 \
    prometheus.io/path=/metrics
    ```

1. No Traffic to Application

    ```bash
    # Generate traffic
    APP_URL=$(kubectl get svc sre-app -n sre-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    for i in {1..50}; do curl -s http://$APP_URL/api/data > /dev/null; sleep 1; done
    ```

1. Data Source Not Configured

    ```bash
    # Restart Grafana to pick up provisioned data source
    kubectl rollout restart deployment/grafana -n monitoring

    # Wait and check
    kubectl rollout status deployment/grafana -n monitoring
    ```

### Issue: Alerts Not Firing

**Symptom:**

No Slack notifications despite issues

**Diagnosis:**

```bash
# Check AlertManager is running
kubectl get pods -n monitoring -l app=alertmanager

# Check AlertManager config
kubectl get configmap alertmanager-config -n monitoring -o yaml

# Check alert rules
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Open: http://localhost:9090/alerts
```

**Solution:**

1. Test Webhook

    ```bash
    # Get webhook URL from secret
    kubectl get secret alertmanager-slack-webhook -n monitoring -o jsonpath='{.data.webhook-url}' | base64 -d

    # Test directly
    curl -X POST WEBHOOK_URL \
    -H 'Content-Type: application/json' \
    -d '{"text":"Test from troubleshooting"}'
    ```

1. Restart AlertManager

    ```bash
    kubectl rollout restart deployment/alertmanager -n monitoring
    kubectl rollout status deployment/alertmanager -n monitoring
    ```

1. Check Alert Rules

    ```bash
    # Verify rules are loaded
    kubectl logs -n monitoring deployment/prometheus | grep -i "rule"

    # Reload Prometheus
    kubectl rollout restart deployment/prometheus -n monitoring
    ```

### Issue: Prometheus High Memory Usage

**Symptom:**

```bash
OOMKilled or high memory usage
```

**Diagnosis:**

```bash
# Check memory usage
kubectl top pod -n monitoring -l app=prometheus

# Check retention settings
kubectl get deployment prometheus -n monitoring -o yaml | grep retention
```

**Solution:**

```bash
# Reduce retention period
kubectl set env deployment/prometheus -n monitoring \
  PROMETHEUS_RETENTION=1d

# Or increase memory limits
kubectl edit deployment prometheus -n monitoring
# Increase memory limits
```

---

## Networking Issues

### Issue: Cannot Access Application

**Symptom:**

```bash
curl: (7) Failed to connect to APP_URL port 80: Connection refused
```

**Diagnosis:**

```bash
# Check service
kubectl get svc sre-app -n sre-app

# Check if LoadBalancer has external IP
kubectl get svc sre-app -n sre-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Check pods are running
kubectl get pods -n sre-app
```

**Solution:**

1. LoadBalancer Provisioning

    ```bash
    # Wait for LoadBalancer (can take 2-3 minutes)
    kubectl get svc sre-app -n sre-app -w

    # Check AWS console for load balancer status
    aws elbv2 describe-load-balancers --region us-east-1
    ```

1. Security Group Issues

    ```bash
    # Check security groups allow traffic
    aws ec2 describe-security-groups --region us-east-1 \
    --filters "Name=tag:kubernetes.io/cluster/sre-showcase-demo,Values=owned"
    ```

### Issue: Pods Cannot Pull Images

**Symptom:**

```bash
Failed to pull image: unauthorized
```

**Diagnosis:**

```bash
# Check image name
kubectl get deployment sre-app -n sre-app -o yaml | grep image:

# Try pulling manually
docker pull ghcr.io/USERNAME/sre-showcase/sre-app:latest
```

**Solution:**

```bash
# Make package public on GitHub
# Go to: https://github.com/USERNAME?tab=packages
# Click sre-app → Package settings → Change visibility → Public

# Or create image pull secret (if private)
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=USERNAME \
  --docker-password=TOKEN \
  -n sre-app

# Add to deployment
kubectl patch serviceaccount default -n sre-app \
  -p '{"imagePullSecrets": [{"name": "ghcr-secret"}]}'
```

---

## Performance Issues

### Issue: High Latency

**Symptom:**

p95 latency > 1s

**Diagnosis:**

```bash
# Check pod resource usage
kubectl top pods -n sre-app

# Check HPA status
kubectl get hpa -n sre-app

# Check for throttling
kubectl describe pod -n sre-app POD_NAME | grep -i throttl
```

**Solution:**

1. Scale Up

    ```bash
    # Manual scale
    kubectl scale deployment sre-app --replicas=4 -n sre-app

    # Or adjust HPA threshold
    kubectl edit hpa sre-app-hpa -n sre-app
    # Lower CPU threshold
    ```

1. Increase Resources

    ```bash
    kubectl edit deployment sre-app -n sre-app
    # Increase CPU/memory limits
    ```

### Issue: HPA Not Scaling

**Symptom:**

HPA shows `⁠<unknown>` for metrics

**Diagnosis:**

```bash
# Check HPA status
kubectl describe hpa sre-app-hpa -n sre-app

# Check metrics-server
kubectl get pods -n kube-system -l k8s-app=metrics-server

# Test metrics
kubectl top pods -n sre-app
```

**Solution:**

```bash
# Install/reinstall metrics-server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Wait for it to be ready
kubectl wait --for=condition=Ready pod -l k8s-app=metrics-server -n kube-system --timeout=300s

# Verify
kubectl top nodes
```

---

## Useful Commands

### Debugging Pods

```bash
# Get pod logs
kubectl logs -n NAMESPACE POD_NAME

# Follow logs
kubectl logs -n NAMESPACE POD_NAME -f

# Previous container logs
kubectl logs -n NAMESPACE POD_NAME --previous

# All pods with label
kubectl logs -n NAMESPACE -l app=sre-app --tail=50

# Execute command in pod
kubectl exec -n NAMESPACE POD_NAME -- COMMAND

# Interactive shell
kubectl exec -it -n NAMESPACE POD_NAME -- /bin/sh
```

### Debugging Services

```bash
# Check service
kubectl get svc -n NAMESPACE SERVICE_NAME

# Describe service
kubectl describe svc -n NAMESPACE SERVICE_NAME

# Check endpoints
kubectl get endpoints -n NAMESPACE SERVICE_NAME

# Test service from within cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://SERVICE_NAME.NAMESPACE:PORT/health
```

### Debugging Networking

```bash
# Check DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup sre-app.sre-app.svc.cluster.local

# Check connectivity
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- \
  curl -v http://sre-app.sre-app:80/health

# Check network policies
kubectl get networkpolicies -A
```

### Debugging Resources

```bash
# Check resource usage
kubectl top nodes
kubectl top pods -A

# Check resource quotas
kubectl get resourcequota -A

# Check limit ranges
kubectl get limitrange -A

# Describe node capacity
kubectl describe nodes | grep -A 5 "Allocated resources"
```

### Emergency Commands

```bash
# Force delete stuck pod
kubectl delete pod POD_NAME -n NAMESPACE --force --grace-period=0

# Drain node
kubectl drain NODE_NAME --ignore-daemonsets --delete-emptydir-data

# Cordon node (prevent scheduling)
kubectl cordon NODE_NAME

# Uncordon node
kubectl uncordon NODE_NAME

# Delete all pods in namespace (careful!)
kubectl delete pods --all -n NAMESPACE
```

---

## Getting More Help

### Check Logs

```bash
# Application logs
kubectl logs -n sre-app -l app=sre-app --tail=100

# Prometheus logs
kubectl logs -n monitoring deployment/prometheus --tail=50

# Grafana logs
kubectl logs -n monitoring deployment/grafana --tail=50

# AlertManager logs
kubectl logs -n monitoring deployment/alertmanager --tail=50
```

### Check Events

```bash
# Recent events in namespace
kubectl get events -n NAMESPACE --sort-by='.lastTimestamp'

# All events
kubectl get events -A --sort-by='.lastTimestamp' | tail -50

# Watch events
kubectl get events -n NAMESPACE -w
```

### Export Diagnostics

```bash
# Export all resources
kubectl get all -A -o yaml > cluster-state.yaml

# Export logs
kubectl logs -n sre-app -l app=sre-app > app-logs.txt

# Export events
kubectl get events -A --sort-by='.lastTimestamp' > events.txt
```

---

## Escalation

If issues persist after trying these solutions:

1. ✅ Check [Architecture Documentation](01-architecture.md)
1. ✅ Review [Setup Guide](02-setup-guide.md)
1. ✅ Check AWS Console for infrastructure issues
1. ✅ Review Terraform state: `⁠terraform show`
1. ✅ Open GitHub issue with diagnostics

---

## Prevention

### Best Practices

- ✅ Always test changes in a separate branch first
- ✅ Monitor dashboards during deployments
- ✅ Keep resource requests/limits appropriate
- ✅ Regularly check for pod restarts
- ✅ Review logs for warnings
- ✅ Clean up resources after demos

### Health Checks

Run these regularly:

```bash
# Quick health check
kubectl get nodes
kubectl get pods -A | grep -v Running
kubectl top nodes
kubectl get hpa -A

# If all green, system is healthy!
```
