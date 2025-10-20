# SLO/SLI Definitions

Service Level Objectives (SLOs) and Service Level Indicators (SLIs) for the SRE Showcase application.

---

## Overview

This document defines the reliability targets for the SRE Showcase application and explains how they are measured and tracked.

---

## Service Level Indicators (SLIs)

SLIs are quantitative measures of service behavior.

### 1. Availability

**Definition:** Percentage of successful HTTP requests

**Measurement:**

```promql
(sum(rate(http_requests_total{status!~"5.."}[5m])) / 
 sum(rate(http_requests_total[5m]))) * 100
```

**Data Source:** Application metrics (`⁠http_requests_total`)

**Collection Interval:** 30 seconds

### 2. Latency

**Definition:** Time taken to process HTTP requests

**Measurement:**

**p50 (Median):**

```bash
histogram_quantile(0.50, 
  sum(rate(http_request_duration_seconds_bucket[5m])) by (le)
)
```

**p95 (95th Percentile):**

```bash
histogram_quantile(0.95, 
  sum(rate(http_request_duration_seconds_bucket[5m])) by (le)
)
```

**p99 (99th Percentile):**

```bash
histogram_quantile(0.99, 
  sum(rate(http_request_duration_seconds_bucket[5m])) by (le)
)
```

**Data Source:** Application metrics (`http_request_duration_seconds`)

**Collection Interval:** 30 seconds

### 3. Error Rate

**Definition:** Percentage of failed HTTP requests (5xx errors)

**Measurement:**

```bash
(sum(rate(http_requests_total{status=~"5.."}[5m])) / 
 sum(rate(http_requests_total[5m]))) * 100
```

**Data Source:** Application metrics (`http_requests_total`)

**Collection Interval:** 30 seconds

### 4. Throughput

**Definition:** Number of requests processed per second

**Measurement:**

```bash
sum(rate(http_requests_total[5m]))
```

**Data Source:** Application metrics (`http_requests_total`)

**Collection Interval:** 30 seconds

---

## Service Level Objectives (SLOs)

SLOs are target values or ranges for SLIs.

1. Availability SLO

    **Target:** 99.5% availability over 30-day rolling window

    **Rationale:**

    - Allows for ~3.6 hours of downtime per month
    - Realistic for a demo/showcase application
    - Balances reliability with development velocity

    **Measurement Window:** 30 days

    **Alert Threshold:** < 99.5% over 24 hours

1. Latency SLO

    **Targets:**

    - **p50 < 50ms**: Median response time
    - **p95 < 200ms**: 95% of requests
    - **p99 < 500ms**: 99% of requests

    **Rationale:**

    - p50: Fast response for typical requests
    - p95: Good experience for most users
    - p99: Acceptable for edge cases

    **Measurement Window:** 5 minutes (rolling)

    **Alert Threshold:** p95 > 1s for 2 minutes

1. Error Rate SLO

    **Target:** < 1% error rate over 5-minute window

    **Rationale:**

    - 99% success rate is acceptable for non-critical services
    - Allows for occasional failures
    - Realistic for demo scenarios

    **Measurement Window:** 5 minutes (rolling)

    **Alert Threshold:** > 5% for 1 minute

---

## Error Budget

### Definition

Error budget is the amount of unreliability we can tolerate while still meeting our SLO.

### Calculation

**Availability Error Budget:**

```bash
Error Budget = 100% - SLO
             = 100% - 99.5%
             = 0.5%
```

**Monthly Downtime Budget:**

```bash
30 days × 24 hours × 60 minutes × 0.5% = 216 minutes = 3.6 hours
```

### Error Budget Policy

| Error Budget Remaining | Action |
|:-----------------------|:-------|
| > 50% | ✅ Normal operations, can take risks |
| 25-50% | ⚠️ Caution, reduce risky changes |
| 10-25% | 🚨 Focus on reliability, freeze features |
| < 10% | 🔥 Emergency, all hands on reliability |

---

## Monitoring and Alerting

### Grafana Dashboard

**Location:** SRE Showcase - Application Dashboard

**Panels (5 total):**

1. Request Rate (RPS)
2. Error Rate (%)
3. Request Latency (p50, p95, p99)
4. Active Pods
5. Requests (Time Window)

**Refresh:** 10 seconds

### Prometheus Alerts

#### HighErrorRate

**Condition:**

```bash
expr: |
  (sum(rate(http_requests_total{status=~"5..", kubernetes_namespace="sre-app"}[5m])) / 
   sum(rate(http_requests_total{kubernetes_namespace="sre-app"}[5m]))) * 100 > 5
for: 1m
```

**Severity:** Critical

**Impact:** SLO violation (error rate > 1%)

**Action:** Investigate immediately, check logs, consider rollback

#### HighLatency

**Condition:**

```bash
expr: |
  histogram_quantile(0.95, 
    sum(rate(http_request_duration_seconds_bucket{kubernetes_namespace="sre-app"}[5m])) by (le)
  ) > 1
for: 2m
```

**Severity:** Warning

**Impact:** SLO violation (p95 > 200ms)

**Action:** Check resource usage, investigate slow queries

#### PodsDown

**Condition:**

```bash
expr: absent(up{kubernetes_namespace="sre-app"}) or count(up{kubernetes_namespace="sre-app"} == 0) > 0
for: 1m
```

**Severity:** Critical

**Impact:** Complete service outage

**Action:** Check pod status, investigate crashes, rollback if needed

---

## SLO Tracking

### Daily Review

**Metrics to Check:**

- Availability over last 24 hours
- Error budget consumption
- Alert frequency
- Incident count

**Tools:**

- Grafana dashboard
- Prometheus queries
- Slack alert history

### Weekly Review

**Metrics to Check:**

- Availability over last 7 days
- Latency trends
- Error rate trends
- Capacity planning

**Actions:**

- Adjust SLOs if needed
- Plan reliability improvements
- Review incident postmortems

### Monthly Review

**Metrics to Check:**

- 30-day availability
- Error budget status
- SLO compliance
- Trend analysis

**Deliverables:**

- SLO report
- Reliability roadmap
- Capacity forecast

---

## Example Queries

### Check Current Availability

```bash
# Last 5 minutes
(sum(rate(http_requests_total{status!~"5..", kubernetes_namespace="sre-app"}[5m])) / 
 sum(rate(http_requests_total{kubernetes_namespace="sre-app"}[5m]))) * 100
```

### Check Error Budget Consumption

```bash
# Errors in last 24 hours
sum(increase(http_requests_total{status=~"5..", kubernetes_namespace="sre-app"}[24h]))

# Total requests in last 24 hours
sum(increase(http_requests_total{kubernetes_namespace="sre-app"}[24h]))

# Error rate
(sum(increase(http_requests_total{status=~"5..", kubernetes_namespace="sre-app"}[24h])) / 
 sum(increase(http_requests_total{kubernetes_namespace="sre-app"}[24h]))) * 100
```

### Check Latency Distribution

```bash
# p50
histogram_quantile(0.50, sum(rate(http_request_duration_seconds_bucket{kubernetes_namespace="sre-app"}[5m])) by (le))

# p95
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{kubernetes_namespace="sre-app"}[5m])) by (le))

# p99
histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket{kubernetes_namespace="sre-app"}[5m])) by (le))
```

---

## SLO Compliance Report

### Template

```bash
SLO Compliance Report
Period: [Start Date] - [End Date]

Availability:
- Target: 99.5%
- Actual: XX.XX%
- Status: ✅ Met / ❌ Missed

Latency (p95):
- Target: < 200ms
- Actual: XXXms
- Status: ✅ Met / ❌ Missed

Error Rate:
- Target: < 1%
- Actual: X.XX%
- Status: ✅ Met / ❌ Missed

Error Budget:
- Allocated: 0.5%
- Consumed: X.XX%
- Remaining: X.XX%

Incidents:
- Count: X
- Total downtime: XX minutes
- MTTR: XX minutes

Actions:
- [Action items from review]
```

---

## Best Practices

### Setting SLOs

1. ✅ **Start conservative**: Easier to tighten than loosen
1. ✅ **Align with user expectations**: What do users actually need?
1. ✅ **Make them measurable**: Use existing metrics
1. ✅ **Keep them simple**: Easy to understand and explain
1. ✅ **Review regularly**: Adjust based on reality

### Monitoring SLOs

1. ✅ **Automate tracking**: Don't rely on manual checks
1. ✅ **Alert on violations**: Know immediately when SLO is at risk
1. ✅ **Track trends**: Look for patterns over time
1. ✅ **Document incidents**: Learn from SLO violations
1. ✅ **Share widely**: Make SLOs visible to all teams

### Using Error Budgets

1. ✅ **Balance reliability and velocity**: Use budget to take calculated risks
1. ✅ **Freeze when exhausted**: Stop risky changes when budget is low
1. ✅ **Reset regularly**: Monthly or quarterly reset
1. ✅ **Make decisions data-driven**: Use budget to prioritize work
1. ✅ **Communicate status**: Keep stakeholders informed

---

## Talking Points

**Why These SLOs?**

> *"I chose 99.5% availability because it's realistic for a demo application while still demonstrating understanding of reliability targets. In production, I would work with stakeholders to determine appropriate SLOs based on user needs and business requirements."*

**How Do You Track SLOs?**

> *"I use Prometheus to collect metrics and Grafana to visualize them. Alerts fire when we're at risk of violating SLOs, giving us time to respond before users are impacted. I also track error budget consumption to balance reliability with development velocity."*

**What Happens When You Miss an SLO?**

> *"First, I'd investigate the root cause and document it in a postmortem. Then I'd determine if the SLO was appropriate - maybe it was too aggressive. If the SLO is correct, I'd prioritize reliability work over new features until we're back within budget. The key is using SLOs to drive decision-making, not just as vanity metrics."*

---

### References

- [Google SRE Book - Service Level Objectives](https://sre.google/sre-book/service-level-objectives/)
- [Google SRE Workbook - Implementing SLOs](https://sre.google/workbook/implementing-slos/)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/)
