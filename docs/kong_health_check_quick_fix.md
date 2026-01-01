# Kong Health Check Quick Fix

## ⚠️ CRITICAL: Hybrid Mode Limitation

**If you're using Kong in Hybrid Mode (Control Plane + Data Plane):**

The Control Plane Admin API **DOES NOT show health check results** in Hybrid Mode. This is a known limitation.

- ❌ **Does NOT work**: `curl $KONG_ADMIN/upstreams/{upstream}/health` (Control Plane Admin API)
- ✅ **Works**: Query Data Plane Status API on port 8100, or verify through behavioral testing

**Reference**: [Kong Health Check in Hybrid Mode](https://surf-ocarina-381.notion.site/Health-Check-in-Hybrid-Mode-2dbf18557a31807cade5c06c24b0928e)

**Solution**: See "Hybrid Mode Workaround" section at the end of this document.

---

## Problem Diagnosis (DB-less Mode Only)

When you run:
```bash
curl -s $KONG_ADMIN/upstreams/hello-upstream/health | jq
```

**❌ INCORRECT Output (No Health Checks):**
```json
{
  "data": [
    {
      "target": "sbxservice.sbxservice.dev.local:8080",
      "weight": 100,
      "id": "..."
      // ❌ Missing: "health" field
      // ❌ Missing: "data.addresses" field
    }
  ]
}
```

**✅ CORRECT Output (With Health Checks):**
```json
{
  "data": [
    {
      "target": "sbxservice.sbxservice.dev.local:8080",
      "weight": 100,
      "health": "HEALTHY",  // ✅ This should be present
      "data": {             // ✅ This should be present
        "addresses": [
          {
            "ip": "10.0.x.x",
            "port": 8080,
            "health": "HEALTHY"
          }
        ]
      }
    }
  ]
}
```

## Root Cause

**Health checks are NOT configured on the `hello-upstream` upstream.**

Kong upstreams don't have health checks enabled by default. You must explicitly configure them.

---

## Quick Fix (3 Steps)

### Step 1: Verify the Problem

```bash
# Check if healthchecks are configured
curl -s $KONG_ADMIN/upstreams/hello-upstream | jq '.healthchecks'
```

**Expected output if NOT configured:**
```json
{
  "active": {
    "healthy": {
      "interval": 0,
      "successes": 0
    },
    "unhealthy": {
      "interval": 0,
      "http_failures": 0,
      "tcp_failures": 0,
      "timeouts": 0
    }
  },
  "passive": {
    "healthy": {
      "successes": 0
    },
    "unhealthy": {
      "http_failures": 0,
      "tcp_failures": 0,
      "timeouts": 0
    }
  }
}
```

All values are `0` = health checks are **disabled**.

### Step 2: Configure Health Checks

```bash
curl -X PATCH $KONG_ADMIN/upstreams/hello-upstream \
  -H "Content-Type: application/json" \
  -d '{
    "healthchecks": {
      "active": {
        "type": "http",
        "http_path": "/actuator/health",
        "timeout": 1,
        "concurrency": 10,
        "https_verify_certificate": false,
        "healthy": {
          "interval": 5,
          "http_statuses": [200, 302],
          "successes": 2
        },
        "unhealthy": {
          "interval": 5,
          "http_statuses": [429, 500, 502, 503, 504],
          "tcp_failures": 2,
          "timeouts": 2,
          "http_failures": 3
        }
      },
      "passive": {
        "type": "http",
        "healthy": {
          "http_statuses": [200, 201, 202, 203, 204, 205, 206, 207, 208, 226, 300, 301, 302, 303, 304, 305, 306, 307, 308],
          "successes": 3
        },
        "unhealthy": {
          "http_statuses": [429, 500, 502, 503, 504],
          "tcp_failures": 2,
          "timeouts": 2,
          "http_failures": 3
        }
      }
    }
  }' | jq
```

**What this does:**
- **Active checks**: Kong will probe `/actuator/health` every 5 seconds
- **Passive checks**: Kong will monitor actual request/response patterns
- **Healthy threshold**: 2 consecutive successful probes → mark HEALTHY
- **Unhealthy threshold**: 3 consecutive failures → mark UNHEALTHY

### Step 3: Verify Health Checks Are Working

Wait 10-15 seconds for health checks to initialize, then:

```bash
curl -s $KONG_ADMIN/upstreams/hello-upstream/health | jq
```

**Expected output:**
```json
{
  "total": 1,
  "node_id": "...",
  "data": [
    {
      "target": "sbxservice.sbxservice.dev.local:8080",
      "weight": 100,
      "health": "HEALTHY",  // ✅ Now present!
      "data": {
        "addresses": [
          {
            "ip": "10.0.x.x",
            "port": 8080,
            "health": "HEALTHY"
          }
        ]
      }
    }
  ]
}
```

✅ You should now see the `"health": "HEALTHY"` field!

---

## Automated Scripts

### Diagnose Script

Run this to check your current configuration:

```bash
/tmp/diagnose-kong-health.sh
```

### Configure Script

Run this to automatically configure health checks:

```bash
/tmp/configure-kong-health.sh
```

---

## Monitor Health in Real-Time

```bash
# Simple monitoring
watch -n 3 "curl -s \$KONG_ADMIN/upstreams/hello-upstream/health | jq '.data[] | {target, health}'"

# Detailed monitoring
watch -n 3 "curl -s \$KONG_ADMIN/upstreams/hello-upstream/health | jq"
```

---

## Test Health Checks Are Working

### Test 1: Verify Active Health Checks

```bash
# Check Kong Data Plane logs for health check activity
aws logs tail /ecs/sbxservice-dev-kong --since 2m | grep -i health

# You should see logs like:
# [healthcheck] (hello-upstream) target marked as 'healthy'
```

### Test 2: Simulate a Failure

```bash
# Stop the hello-service
aws ecs update-service \
  --cluster sbxservice-dev-cluster \
  --service sbxservice-dev-service \
  --desired-count 0

# Wait 15 seconds
sleep 15

# Check health - should be UNHEALTHY
curl -s $KONG_ADMIN/upstreams/hello-upstream/health | jq '.data[] | {target, health}'

# Expected output:
# {
#   "target": "sbxservice.sbxservice.dev.local:8080",
#   "health": "UNHEALTHY"
# }

# Restore the service
aws ecs update-service \
  --cluster sbxservice-dev-cluster \
  --service sbxservice-dev-service \
  --desired-count 1

# Wait 30 seconds
sleep 30

# Check health - should be HEALTHY again
curl -s $KONG_ADMIN/upstreams/hello-upstream/health | jq '.data[] | {target, health}'
```

---

## Common Issues

### Issue 1: Health Checks Not Working After Configuration

**Symptom:** Still no `health` field after configuring.

**Solutions:**
1. Wait 10-15 seconds for first health check cycle
2. Verify Data Planes are connected:
   ```bash
   curl -s $KONG_ADMIN/clustering/data-planes | jq
   ```
3. Check if the health endpoint is accessible:
   ```bash
   curl -v http://sbxservice.sbxservice.dev.local:8080/actuator/health
   ```

### Issue 2: Health Shows "DNS_ERROR"

**Symptom:**
```json
{
  "health": "DNS_ERROR"
}
```

**Solutions:**
1. Verify Cloud Map service discovery is working
2. Check the target hostname resolves:
   ```bash
   # From an ECS task in the same VPC
   nslookup sbxservice.sbxservice.dev.local
   ```

### Issue 3: Health Path Returns 404

**Symptom:** Health checks fail because `/actuator/health` doesn't exist.

**Solutions:**

**Option A:** Change health check path to root:
```bash
curl -X PATCH $KONG_ADMIN/upstreams/hello-upstream \
  -H "Content-Type: application/json" \
  -d '{
    "healthchecks": {
      "active": {
        "http_path": "/"
      }
    }
  }'
```

**Option B:** Use a different health endpoint:
```bash
curl -X PATCH $KONG_ADMIN/upstreams/hello-upstream \
  -H "Content-Type: application/json" \
  -d '{
    "healthchecks": {
      "active": {
        "http_path": "/health"
      }
    }
  }'
```

**Option C:** Check what endpoint your service actually exposes:
```bash
# Test directly
curl -v http://sbxservice.sbxservice.dev.local:8080/
curl -v http://sbxservice.sbxservice.dev.local:8080/health
curl -v http://sbxservice.sbxservice.dev.local:8080/actuator/health
```

---

## Configuration Reference

### Minimal Configuration (Active Only)

```bash
curl -X PATCH $KONG_ADMIN/upstreams/hello-upstream \
  -H "Content-Type: application/json" \
  -d '{
    "healthchecks": {
      "active": {
        "healthy": {
          "interval": 5,
          "successes": 2
        }
      }
    }
  }'
```

### Recommended Configuration (Active + Passive)

See Step 2 above.

### Custom Health Endpoint

```bash
curl -X PATCH $KONG_ADMIN/upstreams/hello-upstream \
  -H "Content-Type: application/json" \
  -d '{
    "healthchecks": {
      "active": {
        "type": "http",
        "http_path": "/your-custom-health-path",
        "healthy": {
          "interval": 10,
          "successes": 1
        },
        "unhealthy": {
          "interval": 10,
          "http_failures": 2
        }
      }
    }
  }'
```

---

## Verification Checklist

After configuration:

- [ ] Run `curl -s $KONG_ADMIN/upstreams/hello-upstream | jq '.healthchecks'` - should show non-zero values
- [ ] Wait 15 seconds for health checks to initialize
- [ ] Run `curl -s $KONG_ADMIN/upstreams/hello-upstream/health | jq` - should show `"health": "HEALTHY"` or `"UNHEALTHY"`
- [ ] Check Kong logs - should show health check activity
- [ ] Test failure scenario - stop backend and verify health changes to UNHEALTHY
- [ ] Test recovery - start backend and verify health changes to HEALTHY

---

## Summary

| Before | After |
|--------|-------|
| No `health` field | `"health": "HEALTHY"` |
| No health checks | Active + Passive checks |
| No probes | Probes every 5 seconds |
| No circuit breaker | Automatic failover |

**Key Takeaway:** Kong upstreams require explicit health check configuration. They are not enabled by default.

---

## Next Steps

1. ✅ Configure health checks (this guide)
2. 📖 Validate with testing scenarios → See `kong_healthcheck_validation_guide.md`
3. 📖 Set up monitoring and alerts
4. 📖 Configure advanced load balancing

---

## Hybrid Mode Workaround

### The Real Issue in Hybrid Mode

If you're running Kong in Hybrid Mode (Control Plane + Data Plane):

**Health checks DO work** - they run on Data Planes and affect traffic routing.

**The problem**: Control Plane Admin API doesn't show health status. This is by design, not a bug.

### How to Verify Health Checks Work in Hybrid Mode

#### Option 1: Access Data Plane Status API (Port 8100)

```bash
# Access Data Plane via service discovery
curl http://kong-gateway.sbxservice.dev.local:8100/status | jq

# Or get Data Plane task IP and query directly
TASK_IP=$(aws ecs list-tasks \
  --cluster sbxservice-dev-cluster \
  --service-name sbxservice-dev-kong-service \
  --desired-status RUNNING \
  --query 'taskArns[0]' \
  --output text | xargs -I {} \
  aws ecs describe-tasks \
  --cluster sbxservice-dev-cluster \
  --tasks {} \
  --query 'tasks[0].containers[0].networkInterfaces[0].privateIpv4Address' \
  --output text)

curl http://$TASK_IP:8100/status | jq
```

#### Option 2: Verify Through Behavioral Testing

This is the most practical approach for Kong OSS in Hybrid Mode:

```bash
# Test 1: Stop a backend task
aws ecs stop-task \
  --cluster sbxservice-dev-cluster \
  --task $(aws ecs list-tasks \
    --cluster sbxservice-dev-cluster \
    --service-name sbxservice-dev-service \
    --desired-status RUNNING \
    --query 'taskArns[0]' \
    --output text) \
  --reason "Health check test"

# Wait for health checks to detect failure
sleep 20

# Test 2: Send traffic - should still work (routes to healthy tasks only)
for i in {1..10}; do
  curl -s $ALB_URL/sbx/api/hello -w "Status: %{http_code}\n"
done

# All succeed = health checks are working! ✅
```

#### Option 3: Monitor Data Plane Logs

```bash
# Check Data Plane logs for health check activity
aws logs tail /ecs/sbxservice-dev-kong --since 5m | grep -i health

# You should see:
# [healthcheck] (hello-upstream) target marked as 'healthy'
# [healthcheck] (hello-upstream) probing target ...
```

### Summary

| Deployment Mode | Admin API Health Status | How to Verify |
|----------------|------------------------|---------------|
| **DB-less Mode** | ✅ Works | `curl $KONG_ADMIN/upstreams/{upstream}/health` |
| **Hybrid Mode** | ❌ Not available | Query Data Plane port 8100, or behavioral testing |
| **Traditional (DB mode, no CP/DP)** | ✅ Works | `curl $KONG_ADMIN/upstreams/{upstream}/health` |

**For Hybrid Mode users**: Don't waste time trying to get health status from Control Plane Admin API. Use Data Plane Status API or verify through testing.

---

## References

- [Kong Health Checks Documentation](https://docs.konghq.com/gateway/latest/how-kong-works/health-checks/)
- [Kong Health Check in Hybrid Mode](https://surf-ocarina-381.notion.site/Health-Check-in-Hybrid-Mode-2dbf18557a31807cade5c06c24b0928e)
- [Kong Healthcheck Validation Guide](kong_healthcheck_validation_guide.md)
- [Kong Admin API Command Book](kong_admin_api_command_book.md)

