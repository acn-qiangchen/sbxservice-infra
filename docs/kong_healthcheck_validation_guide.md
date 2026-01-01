# Kong Health Check Validation Guide

This guide shows you how to configure and validate Kong's active and passive health checks.

## ⚠️ CRITICAL: Hybrid Mode Limitation

**In Kong Hybrid Mode (Control Plane + Data Plane), health check results are NOT available through the Control Plane's Admin API.**

- ❌ **Does NOT work**: `curl $KONG_ADMIN/upstreams/{upstream}/health` (Control Plane Admin API)
- ✅ **Works**: Query Data Plane Status API directly on port 8100

**Reference**: [Kong Health Check in Hybrid Mode](https://surf-ocarina-381.notion.site/Health-Check-in-Hybrid-Mode-2dbf18557a31807cade5c06c24b0928e)

**Solution**: See "Part 6: Accessing Health Checks in Hybrid Mode" at the end of this document.

---

## Overview

Kong supports two types of health checks:

| Type | How It Works | When to Use |
|------|--------------|-------------|
| **Active** | Kong actively probes targets at intervals | Proactive failure detection, independent of traffic |
| **Passive** | Kong monitors actual request/response patterns | Reactive, based on real traffic, no extra probes |

## Prerequisites

```bash
# Set your endpoints
export KONG_ADMIN="http://sbxservice-dev-alb-XXXXXX.us-east-1.elb.amazonaws.com:8001"
export ALB_URL="http://sbxservice-dev-alb-XXXXXX.us-east-1.elb.amazonaws.com"

# Or get from Terraform
cd terraform
export KONG_ADMIN=$(terraform output -raw kong_admin_api_endpoint)
export ALB_URL=$(terraform output -raw alb_dns_name | sed 's/^/http:\/\//')
```

---

## Part 1: Active Health Check Validation

Active health checks send periodic probes to your upstream targets.

### Step 1: Configure Active Health Checks

```bash
# Update hello-upstream with active health checks
curl -X PATCH $KONG_ADMIN/upstreams/hello-upstream \
  -H "Content-Type: application/json" \
  -d '{
    "healthchecks": {
      "active": {
        "type": "http",
        "http_path": "/actuator/health",
        "timeout": 1,
        "concurrency": 10,
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
      }
    }
  }' | jq
```

**Configuration Explained:**
- `http_path`: `/actuator/health` - Spring Boot health endpoint
- `interval`: 5 seconds between checks
- `healthy.successes`: 2 - Need 2 consecutive successes to mark as healthy
- `unhealthy.http_failures`: 3 - Mark unhealthy after 3 consecutive failures
- `timeout`: 1 second - Request timeout

### Step 2: Verify Active Health Check Configuration

```bash
# Check the upstream configuration
curl -s $KONG_ADMIN/upstreams/hello-upstream | jq '.healthchecks.active'
```

**Expected Output:**
```json
{
  "type": "http",
  "http_path": "/actuator/health",
  "timeout": 1,
  "concurrency": 10,
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
}
```

### Step 3: Monitor Active Health Status

```bash
# Check the health status of all targets
curl -s $KONG_ADMIN/upstreams/hello-upstream/health | jq
```

**Expected Output (Healthy):**
```json
{
  "total": 1,
  "node_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "data": [
    {
      "id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
      "created_at": 1234567890,
      "upstream": {
        "id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
      },
      "target": "sbxservice.sbxservice.dev.local:8080",
      "weight": 100,
      "health": "HEALTHY",
      "tags": null,
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

### Step 4: Watch Health Checks in Real-Time

```bash
# Continuously monitor health status (every 3 seconds)
watch -n 3 "curl -s $KONG_ADMIN/upstreams/hello-upstream/health | jq '.data[] | {target: .target, health: .health, addresses: .data.addresses}'"
```

### Step 5: Simulate Unhealthy Backend

**Option A: Stop the ECS Service (Recommended for Testing)**

```bash
# Scale down hello-service to 0 tasks
aws ecs update-service \
  --cluster sbxservice-dev-cluster \
  --service sbxservice-dev-service \
  --desired-count 0

# Wait 15-30 seconds and check health
sleep 20
curl -s $KONG_ADMIN/upstreams/hello-upstream/health | jq '.data[] | {target, health}'

# Expected: "health": "UNHEALTHY"

# Restore service
aws ecs update-service \
  --cluster sbxservice-dev-cluster \
  --service sbxservice-dev-service \
  --desired-count 1

# Wait for it to become healthy again
sleep 30
curl -s $KONG_ADMIN/upstreams/hello-upstream/health | jq '.data[] | {target, health}'
```

**Option B: Add a Dummy Unhealthy Target**

```bash
# Add a fake target that doesn't exist
curl -X POST $KONG_ADMIN/upstreams/hello-upstream/targets \
  -d "target=non-existent-host.local:9999" \
  -d "weight=0"  # Weight 0 means no traffic

# Wait 15 seconds for health checks
sleep 15

# Check health - should show one UNHEALTHY target
curl -s $KONG_ADMIN/upstreams/hello-upstream/health | jq '.data[] | {target, health}'

# Remove the dummy target when done
TARGET_ID=$(curl -s $KONG_ADMIN/upstreams/hello-upstream/targets | jq -r '.data[] | select(.target=="non-existent-host.local:9999") | .id')
curl -X DELETE $KONG_ADMIN/upstreams/hello-upstream/targets/$TARGET_ID
```

### Step 6: Verify Active Health Check Logs

```bash
# Check Kong Data Plane logs for health check activity
aws logs tail /ecs/sbxservice-dev-kong --since 5m --follow | grep -i health

# Look for log entries like:
# [healthcheck] (hello-upstream) target marked as 'healthy'
# [healthcheck] (hello-upstream) target marked as 'unhealthy'
```

---

## Part 2: Passive Health Check Validation

Passive health checks monitor actual traffic to determine target health.

### Step 1: Configure Passive Health Checks

```bash
# Add passive health checks to hello-upstream
curl -X PATCH $KONG_ADMIN/upstreams/hello-upstream \
  -H "Content-Type: application/json" \
  -d '{
    "healthchecks": {
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

**Configuration Explained:**
- `healthy.successes`: 3 - Need 3 successful requests to mark as healthy
- `unhealthy.http_failures`: 3 - Mark unhealthy after 3 failed requests
- `unhealthy.timeouts`: 2 - Mark unhealthy after 2 timeouts
- Works only with **real traffic**, not probes

### Step 2: Configure Both Active and Passive Together

```bash
# Best practice: Use both health checks together
curl -X PATCH $KONG_ADMIN/upstreams/hello-upstream \
  -H "Content-Type: application/json" \
  -d '{
    "healthchecks": {
      "active": {
        "type": "http",
        "http_path": "/actuator/health",
        "timeout": 1,
        "concurrency": 10,
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

### Step 3: Generate Traffic to Trigger Passive Checks

Passive health checks only work with real traffic, so we need to send requests:

```bash
# Send successful requests (should keep target healthy)
for i in {1..10}; do
  curl -s $ALB_URL/sbx/api/hello -o /dev/null -w "Response: %{http_code}\n"
  sleep 1
done

# Check health status
curl -s $KONG_ADMIN/upstreams/hello-upstream/health | jq '.data[] | {target, health}'
```

### Step 4: Simulate Failures for Passive Health Checks

**Method 1: Use a Bad Route (Safer)**

```bash
# Create a route that will cause backend errors
curl -X POST $KONG_ADMIN/services/hello-service/routes \
  -d "name=hello-bad-endpoint" \
  -d "paths[]=/hello-bad" \
  -d "strip_path=false"  # Send "/hello-bad" to backend (doesn't exist)

# Send requests to trigger 404s (may trigger passive health check)
for i in {1..5}; do
  curl -s $ALB_URL/sbx/api/hello-bad -w "HTTP %{http_code}\n"
  sleep 1
done

# Check if passive health check detected issues
curl -s $KONG_ADMIN/upstreams/hello-upstream/health | jq

# Clean up
curl -X DELETE $KONG_ADMIN/routes/hello-bad-endpoint
```

**Method 2: Temporarily Stop Backend (More Realistic)**

```bash
# 1. Start monitoring health in another terminal
watch -n 2 "curl -s $KONG_ADMIN/upstreams/hello-upstream/health | jq '.data[] | {target, health}'"

# 2. Stop the backend service
aws ecs update-service \
  --cluster sbxservice-dev-cluster \
  --service sbxservice-dev-service \
  --desired-count 0

# 3. Send traffic (will fail)
for i in {1..10}; do
  curl -s $ALB_URL/sbx/api/hello -w "HTTP %{http_code}\n" || echo "Failed"
  sleep 1
done

# 4. Observe:
# - Active health check marks it unhealthy (within 5-10 seconds)
# - Passive health check marks it unhealthy (after 3 failures from traffic)

# 5. Restore service
aws ecs update-service \
  --cluster sbxservice-dev-cluster \
  --service sbxservice-dev-service \
  --desired-count 1

# 6. Wait and send traffic again
sleep 30
for i in {1..5}; do
  curl -s $ALB_URL/sbx/api/hello -w "HTTP %{http_code}\n"
  sleep 1
done

# 7. Check health - should be HEALTHY again
curl -s $KONG_ADMIN/upstreams/hello-upstream/health | jq
```

---

## Part 3: Multi-Target Load Balancing Validation

Test health checks with multiple backend targets.

### Step 1: Add Multiple Targets

```bash
# First, let's see current targets
curl -s $KONG_ADMIN/upstreams/hello-upstream/targets | jq '.data[] | {target, weight}'

# Add a second target (for testing, we'll add the same service with different weight)
# In production, these would be different backend instances
curl -X POST $KONG_ADMIN/upstreams/hello-upstream/targets \
  -d "target=dummy-backend-1.local:8080" \
  -d "weight=50"

curl -X POST $KONG_ADMIN/upstreams/hello-upstream/targets \
  -d "target=dummy-backend-2.local:8080" \
  -d "weight=50"

# Check all targets
curl -s $KONG_ADMIN/upstreams/hello-upstream/targets | jq '.data[] | {target, weight}'
```

### Step 2: Monitor Multi-Target Health

```bash
# View health of all targets
curl -s $KONG_ADMIN/upstreams/hello-upstream/health | jq '{
  total: .total,
  targets: [.data[] | {
    target: .target,
    weight: .weight,
    health: .health
  }]
}'

# Expected output:
# {
#   "total": 3,
#   "targets": [
#     {"target": "sbxservice.sbxservice.dev.local:8080", "weight": 100, "health": "HEALTHY"},
#     {"target": "dummy-backend-1.local:8080", "weight": 50, "health": "UNHEALTHY"},
#     {"target": "dummy-backend-2.local:8080", "weight": 50, "health": "UNHEALTHY"}
#   ]
# }
```

### Step 3: Verify Load Balancing Only to Healthy Targets

```bash
# Send requests - Kong should route only to healthy target
for i in {1..10}; do
  curl -s $ALB_URL/sbx/api/hello -w "Status: %{http_code}, Time: %{time_total}s\n"
  sleep 0.5
done

# All requests should succeed because Kong routes only to healthy targets
```

### Step 4: Clean Up Dummy Targets

```bash
# Remove dummy targets
curl -s $KONG_ADMIN/upstreams/hello-upstream/targets | jq -r '.data[] | select(.target | contains("dummy")) | .id' | while read id; do
  curl -X DELETE $KONG_ADMIN/upstreams/hello-upstream/targets/$id
  echo "Deleted target: $id"
done

# Verify only real target remains
curl -s $KONG_ADMIN/upstreams/hello-upstream/targets | jq '.data[] | {target, weight}'
```

---

## Part 4: Health Check Metrics and Monitoring

### View Health Status Details

```bash
# Detailed health information
curl -s $KONG_ADMIN/upstreams/hello-upstream/health | jq '{
  upstream: "hello-upstream",
  total_targets: .total,
  node_id: .node_id,
  targets: [.data[] | {
    target: .target,
    weight: .weight,
    health: .health,
    addresses: [.data.addresses[] | {
      ip: .ip,
      port: .port,
      health: .health
    }]
  }]
}'
```

### Create a Health Check Monitor Script

```bash
# Create a monitoring script
cat > /tmp/monitor-kong-health.sh << 'EOF'
#!/bin/bash

KONG_ADMIN="${KONG_ADMIN:-http://localhost:8001}"
UPSTREAM="${1:-hello-upstream}"

echo "Monitoring Kong Upstream Health: $UPSTREAM"
echo "Press Ctrl+C to stop"
echo ""

while true; do
  clear
  echo "========================================"
  echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "========================================"
  
  # Get health status
  curl -s $KONG_ADMIN/upstreams/$UPSTREAM/health | jq -r '
    "Total Targets: \(.total)",
    "Node ID: \(.node_id)",
    "",
    "Target Health Status:",
    "---",
    (.data[] | 
      "Target: \(.target)",
      "  Weight: \(.weight)",
      "  Health: \(.health)",
      "  Addresses: \(.data.addresses | length)",
      (.data.addresses[] | "    - \(.ip):\(.port) -> \(.health)"),
      ""
    )
  '
  
  sleep 3
done
EOF

chmod +x /tmp/monitor-kong-health.sh

# Run the monitor
/tmp/monitor-kong-health.sh hello-upstream
```

### Check Health Events in Logs

```bash
# Monitor Kong logs for health check events
aws logs tail /ecs/sbxservice-dev-kong --since 10m --follow \
  | grep -E "(health|upstream|target)" --color=always

# Or use CloudWatch Insights query
aws logs start-query \
  --log-group-name /ecs/sbxservice-dev-kong \
  --start-time $(date -u -d '5 minutes ago' +%s) \
  --end-time $(date -u +%s) \
  --query-string 'fields @timestamp, @message
    | filter @message like /health/
    | sort @timestamp desc
    | limit 50'
```

---

## Part 5: Testing Scenarios

### Scenario 1: Circuit Breaker Behavior

```bash
echo "=== Testing Circuit Breaker Behavior ==="

# 1. Verify current health
curl -s $KONG_ADMIN/upstreams/hello-upstream/health | jq '.data[] | {target, health}'

# 2. Stop backend
aws ecs update-service --cluster sbxservice-dev-cluster \
  --service sbxservice-dev-service --desired-count 0

echo "Backend stopped. Waiting for health checks to detect failure..."
sleep 15

# 3. Check health - should be UNHEALTHY
curl -s $KONG_ADMIN/upstreams/hello-upstream/health | jq '.data[] | {target, health}'

# 4. Try to send request - should fail gracefully
curl -v $ALB_URL/sbx/api/hello 2>&1 | grep -E "(HTTP|503)"

# 5. Restore backend
aws ecs update-service --cluster sbxservice-dev-cluster \
  --service sbxservice-dev-service --desired-count 1

echo "Backend restarted. Waiting for health checks to detect recovery..."
sleep 45

# 6. Check health - should be HEALTHY
curl -s $KONG_ADMIN/upstreams/hello-upstream/health | jq '.data[] | {target, health}'

# 7. Send request - should succeed
curl $ALB_URL/sbx/api/hello

echo "=== Test Complete ==="
```

### Scenario 2: Gradual Health Recovery

```bash
echo "=== Testing Gradual Health Recovery ==="

# Configure stricter health checks
curl -X PATCH $KONG_ADMIN/upstreams/hello-upstream \
  -H "Content-Type: application/json" \
  -d '{
    "healthchecks": {
      "active": {
        "healthy": {
          "interval": 3,
          "successes": 3
        }
      }
    }
  }'

# Stop and restart service
aws ecs update-service --cluster sbxservice-dev-cluster \
  --service sbxservice-dev-service --desired-count 0

sleep 10

aws ecs update-service --cluster sbxservice-dev-cluster \
  --service sbxservice-dev-service --desired-count 1

# Monitor recovery in real-time
echo "Monitoring health status (Ctrl+C to stop)..."
watch -n 2 "curl -s $KONG_ADMIN/upstreams/hello-upstream/health | jq '.data[] | {target, health}'"

# Should see: UNHEALTHY -> wait for task to start -> 3 successful checks -> HEALTHY
```

### Scenario 3: Mixed Health States

```bash
echo "=== Testing Mixed Health States (Multiple Targets) ==="

# Add multiple targets (one real, two fake)
curl -X POST $KONG_ADMIN/upstreams/hello-upstream/targets \
  -d "target=fake1.local:8080" -d "weight=50"

curl -X POST $KONG_ADMIN/upstreams/hello-upstream/targets \
  -d "target=fake2.local:8080" -d "weight=50"

sleep 10

# Check health - should show mixed state
curl -s $KONG_ADMIN/upstreams/hello-upstream/health | jq '.data[] | {target, health}'

# Send traffic - should only go to healthy target
echo "Sending 10 requests..."
for i in {1..10}; do
  curl -s $ALB_URL/sbx/api/hello -w "HTTP %{http_code}\n" | grep -E "(200|502|503)"
done

echo "All requests should succeed (routed only to healthy target)"

# Cleanup
curl -s $KONG_ADMIN/upstreams/hello-upstream/targets | \
  jq -r '.data[] | select(.target | contains("fake")) | .id' | \
  while read id; do curl -X DELETE $KONG_ADMIN/upstreams/hello-upstream/targets/$id; done
```

---

## Part 6: Verification Checklist

### ✅ Active Health Check Validation

- [ ] Health check configuration is correct
- [ ] Kong sends probes to `/actuator/health` endpoint
- [ ] Healthy targets show `"health": "HEALTHY"`
- [ ] Stopping backend causes health to change to `"UNHEALTHY"` within 15 seconds
- [ ] Starting backend causes health to change to `"HEALTHY"` after successful probes
- [ ] Health check logs appear in Kong Data Plane logs

### ✅ Passive Health Check Validation

- [ ] Passive health check configuration is correct
- [ ] Sending successful requests keeps target healthy
- [ ] Sending failed requests (3+) marks target unhealthy
- [ ] Works in conjunction with active health checks
- [ ] Circuit breaker prevents traffic to unhealthy targets

### ✅ Load Balancing with Health Checks

- [ ] Multiple targets can be added
- [ ] Each target shows independent health status
- [ ] Traffic is routed only to healthy targets
- [ ] Unhealthy targets are automatically excluded from load balancing
- [ ] Health recovery brings targets back into rotation

---

## Troubleshooting

### Health Checks Not Working

**Check 1: Verify health check path is accessible**
```bash
# Test the health endpoint directly
curl -v http://sbxservice.sbxservice.dev.local:8080/actuator/health
```

**Check 2: Verify Data Plane can reach targets**
```bash
# Check security groups allow traffic from Kong DP to backend
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=sbxservice-dev-ecs-sg" \
  --query 'SecurityGroups[].IpPermissions'
```

**Check 3: Review health check configuration**
```bash
curl -s $KONG_ADMIN/upstreams/hello-upstream | jq '.healthchecks'
```

### Health Shows "HEALTHCHECKS_OFF"

This means health checks are not configured. Apply the configuration from Part 1 or Part 2.

```bash
# Verify
curl -s $KONG_ADMIN/upstreams/hello-upstream/health | jq .data[].health
```

---

## Summary

| Check Type | Pros | Cons | Best For |
|------------|------|------|----------|
| **Active** | Proactive, independent of traffic | Extra network overhead | Production systems, predictable failure detection |
| **Passive** | No extra load, based on real traffic | Requires traffic, slower detection | High-traffic APIs, cost-sensitive environments |
| **Both** | Best of both worlds | Slightly more complex config | Recommended for production |

**Recommendation:** Use **both active and passive** health checks together for the most robust health monitoring.

---

---

## Part 6: Accessing Health Checks in Hybrid Mode

### The Problem

In Kong's Hybrid Mode architecture:
- Health checks **run on Data Planes** (each DP maintains its own health state)
- Control Plane Admin API (`/upstreams/{upstream}/health`) **does NOT show real-time health status**
- The Admin API may show stale data or no health information at all

**Reference**: [Kong Health Check in Hybrid Mode](https://surf-ocarina-381.notion.site/Health-Check-in-Hybrid-Mode-2dbf18557a31807cade5c06c24b0928e)

### Solution: Query Data Plane Status API

Each Data Plane exposes a Status API on **port 8100** that includes health check information.

#### Method 1: Access Data Plane Status API via Cloud Map

```bash
# Access Data Plane via internal service discovery
curl http://kong-gateway.sbxservice.dev.local:8100/status | jq

# Look for upstream health in the response
curl http://kong-gateway.sbxservice.dev.local:8100/upstreams | jq
```

#### Method 2: Access Data Plane Directly via ECS Task IP

```bash
# Get Data Plane task IPs
aws ecs list-tasks \
  --cluster sbxservice-dev-cluster \
  --service-name sbxservice-dev-kong-service \
  --desired-status RUNNING \
  --query 'taskArns[]' \
  --output text | while read task_arn; do
    TASK_IP=$(aws ecs describe-tasks \
      --cluster sbxservice-dev-cluster \
      --tasks $task_arn \
      --query 'tasks[0].containers[0].networkInterfaces[0].privateIpv4Address' \
      --output text)
    
    echo "Data Plane IP: $TASK_IP"
    
    # Query health from this specific Data Plane
    curl -s http://$TASK_IP:8100/status | jq
done
```

#### Method 3: Expose Data Plane Status API via ALB (Recommended)

Update your infrastructure to expose port 8100 through the ALB for easier access:

**Add to `terraform/modules/ecs/main.tf`:**

```hcl
# ALB listener for Kong Data Plane Status API
resource "aws_lb_listener" "kong_status" {
  count             = var.kong_enabled ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = 8100
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.kong_status[0].arn
  }
}

# Target group for Kong Status API
resource "aws_lb_target_group" "kong_status" {
  count       = var.kong_enabled ? 1 : 0
  name        = "${var.project_name}-${var.environment}-kong-status"
  port        = 8100
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/status"
    matcher             = "200"
  }
}
```

Then access via:
```bash
curl http://$ALB_URL:8100/status | jq
```

### Verifying Health Checks Work (Without Admin API)

Since you can't use the Control Plane Admin API, verify health checks through behavior:

#### Test 1: Verify Circuit Breaker Behavior

```bash
# Stop a backend task
aws ecs stop-task \
  --cluster sbxservice-dev-cluster \
  --task $(aws ecs list-tasks \
    --cluster sbxservice-dev-cluster \
    --service-name sbxservice-dev-service \
    --desired-status RUNNING \
    --query 'taskArns[0]' \
    --output text) \
  --reason "Testing health check"

# Wait for health checks to detect failure (15-20 seconds)
sleep 20

# Send requests - should still succeed (routes to healthy task only)
for i in {1..10}; do
  curl -s $ALB_URL/sbx/api/hello -w "Status: %{http_code}\n" -o /dev/null
done

# All requests should succeed = health checks are working!
```

#### Test 2: Monitor Data Plane Logs for Health Check Activity

```bash
# Check Data Plane logs for health check messages
aws logs tail /ecs/sbxservice-dev-kong --since 5m | grep -i health

# You should see:
# [healthcheck] (hello-upstream) target marked as 'healthy'
# [healthcheck] (hello-upstream) target marked as 'unhealthy'
```

#### Test 3: Check Service Discovery Health

```bash
# Verify backend tasks are registered
aws servicediscovery discover-instances \
  --namespace-name sbxservice.dev.local \
  --service-name sbxservice \
  --query 'Instances[].{IP:Attributes.AWS_INSTANCE_IPV4,Port:Attributes.AWS_INSTANCE_PORT}'
```

### Alternative: Use Kong Vitals (Enterprise Only)

If you need proper health monitoring in Hybrid Mode, Kong Enterprise provides:
- **Kong Vitals**: Real-time metrics dashboard
- **Prometheus Plugin**: Export metrics to Prometheus/Grafana
- **Status API aggregation**: Better visibility across Data Planes

For Kong OSS (free version), you must:
1. Query each Data Plane Status API individually, OR
2. Verify health checks work through behavioral testing (circuit breaker, logs)

### Summary: Health Check Access in Hybrid Mode

| Method | Works in Hybrid Mode? | How to Access |
|--------|----------------------|---------------|
| Control Plane Admin API `/upstreams/{upstream}/health` | ❌ No | Not available |
| Data Plane Status API (port 8100) | ✅ Yes | `http://kong-dp:8100/status` |
| Data Plane Logs | ✅ Yes | AWS CloudWatch Logs |
| Behavioral Testing (circuit breaker) | ✅ Yes | Send traffic, observe failover |
| Kong Vitals Dashboard | ✅ Yes (Enterprise only) | Kong Manager Enterprise |

**Recommendation for Kong OSS Hybrid Mode:**
- Configure health checks properly (they DO work!)
- Verify through behavioral testing and logs
- Don't rely on Control Plane Admin API for health status
- Consider exposing Data Plane Status API (port 8100) via ALB for monitoring

---

## References

- [Kong Health Checks Documentation](https://docs.konghq.com/gateway/latest/how-kong-works/health-checks/)
- [Kong Health Check in Hybrid Mode](https://surf-ocarina-381.notion.site/Health-Check-in-Hybrid-Mode-2dbf18557a31807cade5c06c24b0928e)
- [Kong Upstream Object](https://docs.konghq.com/gateway/latest/admin-api/upstreams/)
- [Kong Load Balancing](https://docs.konghq.com/gateway/latest/how-kong-works/load-balancing/)

