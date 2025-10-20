# Load Tests

Collection of k6 load tests for the SRE Showcase application.

---

## Available Tests

### 1. Spike Test (`spike-test.js`)

**Purpose:** Test auto-scaling behavior with sudden traffic spike

**Profile:**

- Ramp: 10s to 20 users
- Spike: 90s at 150 users
- Ramp down: 30s to 20 users

**Usage:**

```bash
./run-spike-test.sh
```

**Expected Outcome:**

- HPA scales pods from 2 → 3-6
- Latency increases during spike
- Prometheus `HighLatency` alert fires
- System recovers after spike
- Pods scale back down after 5 minutes

---

### 2. Load Test (`load-test.js`)

**Purpose:** Sustained load to verify stability

**Profile:**

- Ramp: 1m to 50 users
- Sustain: 5m at 50 users
- Ramp down: 1m to 0

**Usage:**

```bash
./run-load-test.sh
```

**Expected Outcome:**

- HPA scales pods from 2 → 4
- System handles sustained load
- Latency remains stable
- No errors, no alerts fired
- Resource usage steady

---

### 3. Stress Test (`stress-test.js`)

**Purpose:** Find system breaking point

**Profile:**

- Progressive ramp: 50 → 100 → 200 → 300 → 400 users
- 2 minutes at each level

**Usage:**

```bash
./run-stress-test.sh
```

**Expected Outcome:**

- HPA scales pods from 2 → 10
- Identify maximum capacity
- Observe degradation patterns
- Find resource bottlenecks
- Prometheus `HighLatency` alert fires

---

## Monitoring During Tests

### Grafana Dashboard

```bash
# Access Grafana
kubectl port-forward -n monitoring svc/grafana 3000:80
# Open: http://localhost:3000
```

Watch:

- Request rate
- Error rate
- Latency percentiles
- Active pods

### HPA Scaling

```bash
kubectl get hpa -n sre-app -w
```

### Pod Status

```bash
kubectl get pods -n sre-app -w
```

---

## Interpreting Results

### Good Performance

- ✅ p95 latency < 500ms
- ✅ Error rate < 1%
- ✅ HPA scales appropriately
- ✅ System recovers after load

### Performance Issues

- ❌ p95 latency > 1s
- ❌ Error rate > 5%
- ❌ Pods crash or restart
- ❌ Slow recovery after load

---

## Customization

All tests support the `BASE_URL` environment variable:

```bash
BASE_URL="http://your-app-url" k6 run spike-test.js
```

---

## Test Results

### Example Output

```bash
     ✓ status is 200
     ✓ response time < 500ms

     checks.........................: 100.00% ✓ 3888      ✗ 0
     data_received..................: 639 kB  5.3 kB/s
     data_sent......................: 262 kB  2.2 kB/s
     http_req_duration..............: avg=167ms min=142ms med=169ms max=292ms p(90)=277ms p(95)=285ms
     http_req_failed................: 0.00%   ✓ 0         ✗ 1944
     http_reqs......................: 1944    16.03/s
     iterations.....................: 1944    16.03/s
     vus............................: 6       min=1       max=100
     vus_max........................: 100     min=100     max=100
```

---

## Troubleshooting

### Issue: Connection Refused

**Error:**

```bash
WARN[0001] Request Failed error="Get \"http://...\": dial tcp: connect: connection refused"
```

**Solution:**

```bash
# Check if app is running
kubectl get pods -n sre-app

# Get correct URL
kubectl get svc sre-app -n sre-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

---

### Issue: High Failure Rate

**Error:**

```bash
http_req_failed................: 50.00%  ✓ 972       ✗ 972
```

**Solution:**

```bash
# Check pod logs
kubectl logs -n sre-app -l app=sre-app --tail=50

# Check if pods are ready
kubectl get pods -n sre-app

# Reduce load
# Edit test file and lower target users
```

---

### Issue: Timeout Errors

**Error:**

```bash
WARN[0030] Request Failed error="Get \"http://...\": context deadline exceeded"
```

**Solution:**

```bash
# Increase timeout in test
# Add to options in .js file:
export const options = {
  // ...
  timeout: '60s',
};
```

---

## Advanced Usage

### Running Tests in Parallel

```bash
# Terminal 1: Spike test
./run-spike-test.sh

# Terminal 2: Watch HPA
kubectl get hpa -n sre-app -w

# Terminal 3: Watch Grafana
open http://GRAFANA_URL
```

---

### Custom Test Scenarios

Create your own test by copying an existing one:

```bash
# Copy template
cp spike-test.js custom-test.js

# Edit stages
vim custom-test.js

# Run
BASE_URL="http://your-url" k6 run custom-test.js
```

---

### Saving Results

```bash
# Save results to JSON
k6 run spike-test.js --out json=results.json

# Save summary
k6 run spike-test.js --summary-export=summary.json
```

---

## Best Practices

### Before Running Tests

- [ ] Verify application is healthy
- [ ] Check current pod count
- [ ] Open Grafana dashboard
- [ ] Start watching HPA
- [ ] Notify team (if shared environment)

### During Tests

- [ ] Monitor Grafana in real-time
- [ ] Watch for error spikes
- [ ] Observe auto-scaling behavior
- [ ] Check Slack for alerts

### After Tests

- [ ] Wait for system to stabilize
- [ ] Verify pods scaled back down
- [ ] Check for any errors in logs
- [ ] Document any issues found
- [ ] Review SLO compliance
- [ ] Check Slack for resolved issues

---

## Load Test Checklist

### Spike Test

- [ ] Pods scale up (2 → 3+)
- [ ] Latency increases but stays < 1s
- [ ] No errors (< 1%)
- [ ] Pods scale back down after 5 min
- [ ] Alert fires when latency threshold exceeded

### Load Test

- [ ] Pods scale up (2 → 4+)
- [ ] System handles sustained load
- [ ] Latency remains stable
- [ ] No pod restarts, no alerts fired
- [ ] Resource usage steady
- [ ] No memory leaks

### Stress Test

- [ ] Pods scale up (2 → 8+)
- [ ] Identify breaking point
- [ ] Document max capacity
- [ ] Observe graceful degradation
- [ ] Alerts fire appropriately
- [ ] System recovers after test

---

## References

- [k6 Documentation](https://k6.io/docs/)
- [k6 Test Types](https://k6.io/docs/test-types/introduction/)
- [k6 Metrics](https://k6.io/docs/using-k6/metrics/)
- [HTTP Performance Testing](https://k6.io/docs/using-k6-browser/recommended-practices/)
