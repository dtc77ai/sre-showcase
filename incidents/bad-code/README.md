# Incident 2: Bad Code Deployment (Crash Loop)

## Scenario

A developer deployed code that crashes on startup due to a database connection failure. Pods enter a crash loop and never become Ready.

## Steps to Simulate

### Automatic Process

```bash
./simulate.sh
```

### Step by Step Process

1. **Build and Push Broken Image**

    ```bash
    # Backup current main.py
    cp app/main.py app/main-working.py

    # Copy broken version
    cp incidents/bad-code/main-broken.py app/main.py

    # Build broken image
    cd app
    docker build --platform linux/amd64 -t ghcr.io/YOUR_USERNAME/sre-showcase/sre-app:broken .
    docker push ghcr.io/YOUR_USERNAME/sre-showcase/sre-app:broken

    # Restore working version
    cp main-working.py main.py
    cd ..
    ```

1. **Deploy Broken Code**

    ```bash
    kubectl set image deployment/sre-app \
    sre-app=ghcr.io/YOUR_USERNAME/sre-showcase/sre-app:broken \
    -n sre-app
    ```

1. **Observe the incident:**

    **Watch pod crash:**

    ```bash
    kubectl get pods -n sre-app -w
    ```

    You'll see:
    - New pod in `⁠CrashLoopBackOff` state
    - Restart count increasing
    - 2/3 pods Ready

    **Check logs:**

    ```bash
    POD=$(kubectl get pod -n sre-app -l app=sre-app -o jsonpath='{.items[0].metadata.name}')
    kubectl logs -n sre-app $POD
    ```

    You'll see the error: "Database connection failed"

    **Prometheus Alert:**

    ```bash
    kubectl port-forward -n monitoring svc/prometheus 9090:9090
    ```

    Open <http://localhost:9090/alerts> - `⁠PodsDown` and `HealthCheckFailing` alerts should fire

    **Slack:**

    Check #sre-alerts for notification

    **Grafana:**

    - Request Rate drops

    - Active Pods shows 2 (the original pods)

1. **Rollback**

    ```bash
    # Rollback to previous version
    kubectl rollout undo deployment/sre-app -n sre-app

    # Watch recovery
    kubectl rollout status deployment/sre-app -n sre-app
    ```

1. **Verify recovery:**

    ```bash
    # Check pods are healthy
    kubectl get pods -n sre-app

    # Test application
    APP_URL=$(kubectl get svc sre-app -n sre-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    curl http://$APP_URL/health
    ```

## Expected Timeline

- **T+0**: Deploy broken code

- **T+30s**: New pod start crashing

- **T+1m**: Alert fires due to bad pod (PodsDown, HealthCheckFailing)

- **T+1m**: Slack notification

- **T+2m**: Rollback initiated

- **T+3m**: Pods healthy, alert resolves

## Root Cause

Simulated database connection failure in application startup code.

## Prevention

- Add startup health checks in CI/CD

- Use canary deployments

- Implement proper error handling for external dependencies
