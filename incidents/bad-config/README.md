# Incident 3: Bad Configuration Change

## Scenario

Someone accidentally set the deployment replicas to 0, causing all application pods to be terminated.

## Steps to Simulate

### Automatic Process

```bash
./simulate.sh
```

### Step by Step Process

1. **Apply Broken Configuration**

    ```bash
    kubectl apply -f incidents/bad-config/deployment-broken.yaml
    ```

1. **Observe the incident:**

    **Watch pods terminating:**

    ```bash
    kubectl get pods -n sre-app -w
    ```

    All pods will terminate, leaving 0 pods running.

    **Check deployment:**

    ```bash
    kubectl get deployment sre-app -n sre-app
    ```

    Shows: `⁠READY 0/0`

    **Prometheus Alert:**

    ```bash
    kubectl port-forward -n monitoring svc/prometheus 9090:9090
    ```

    Open <http://localhost:9090/alerts> - `⁠PodsDown` alert should fire

    **Slack:**

    Check #sre-alerts for notification

    **Grafana:**

    - Request Rate drops to 0

    - Active Pods shows 0

    - Application becomes unavailable

    **Test application (will fail):**

    ```bash
    APP_URL=$(kubectl get svc sre-app -n sre-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    curl http://$APP_URL/health
    # Connection refused or timeout
    ```

1. **Fix the Configuration**

    ```bash
    # Scale back to 2 replicas
    kubectl scale deployment sre-app --replicas=2 -n sre-app

    # Or reapply correct configuration
    kubectl apply -k k8s/app/
    ```

1. **Verify recovery:**

    ```bash
    # Watch pods starting
    kubectl get pods -n sre-app -w

    # Wait for pods to be Ready
    kubectl rollout status deployment/sre-app -n sre-app

    # Test application
    curl http://$APP_URL/health
    ```

## Expected Timeline

- **T+0**: Apply broken config (replicas: 0)

- **T+10s**: All pods terminated

- **T+1m**: Alert fires (PodsDown)

- **T+1m**: Slack notification

- **T+2m**: Fix applied (scale to 2)

- **T+3m**: Pods healthy, alert resolves

## Root Cause

Configuration error: deployment replicas set to 0 instead of 2.

## Prevention

- Code review for infrastructure changes

- Use GitOps with approval workflows

- Set minimum replica count in policy (OPA/Kyverno)

- Alerts for replica count changes
