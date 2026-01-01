# Kong Gateway Troubleshooting Guide

Complete troubleshooting guide for Kong Gateway OSS in Hybrid Mode, including health checks, connectivity issues, and common problems.

---

## Table of Contents

1. [Quick Diagnostics](#quick-diagnostics)
2. [Common Issues](#common-issues)
3. [Health Check Issues](#health-check-issues)
4. [Hybrid Mode Specific Issues](#hybrid-mode-specific-issues)
5. [Database Issues](#database-issues)
6. [Network and Connectivity](#network-and-connectivity)
7. [Performance Issues](#performance-issues)
8. [Debugging Commands](#debugging-commands)

---

## Quick Diagnostics

Run this comprehensive health check:

```bash
#!/bin/bash
echo "=== Kong Gateway Health Check ==="

# 1. Check Control Plane
echo "1. Control Plane Status:"
curl -s $KONG_ADMIN/status | jq

# 2. Check Data Planes Connected
echo "2. Data Planes Connected:"
curl -s $KONG_ADMIN/clustering/data-planes | jq '.data | length'

# 3. Check Services
echo "3. Services Configured:"
curl -s $KONG_ADMIN/services | jq '.data | length'

# 4. Check Routes
echo "4. Routes Configured:"
curl -s $KONG_ADMIN/routes | jq '.data | length'

# 5. Test API Access
echo "5. Testing API Access:"
curl -s $ALB_URL/sbx/api/hello -w "Status: %{http_code}\n"

echo "=== Health Check Complete ==="
```

---

## Common Issues

### Issue 1: Control Plane Not Starting

**Symptoms:**
- Admin API not accessible
- `curl $KONG_ADMIN/status` fails
- Kong CP container keeps restarting

**Possible Causes & Solutions:**

#### Cause A: Database Not Accessible

```bash
# Check if database is running
aws rds describe-db-instances \
  --db-instance-identifier sbxservice-dev-kong-db \
  --query 'DBInstances[0].DBInstanceStatus'

# Or for ECS PostgreSQL
aws ecs describe-services \
  --cluster sbxservice-dev-cluster \
  --services sbxservice-dev-postgres-service \
  --query 'services[0].runningCount'

# Check Kong CP logs for database errors
aws logs tail /ecs/sbxservice-dev-kong-cp --since 5m | grep -i "database\|postgres"
```

**Fix:**
- Ensure database security group allows traffic from Kong CP
- Verify database credentials in Secrets Manager
- Check database is in "available" state

#### Cause B: Database Migrations Failed

```bash
# Check migration logs
aws logs tail /ecs/sbxservice-dev-kong-cp --since 10m | grep -i migration
```

**Fix:**
- Manually run migrations if needed
- Ensure database user has CREATE TABLE permissions
- Check PostgreSQL version compatibility (use version 13)

#### Cause C: Incorrect Environment Variables

```bash
# Verify Kong CP task definition
aws ecs describe-task-definition \
  --task-definition sbxservice-dev-kong-cp \
  --query 'taskDefinition.containerDefinitions[0].environment'
```

**Fix:**
- Verify `KONG_ROLE=control_plane`
- Verify `KONG_DATABASE=postgres`
- Check PG_HOST, PG_PORT, PG_USER, PG_DATABASE are correct

---

### Issue 2: Data Planes Not Connected

**Symptoms:**
```bash
$ curl $KONG_ADMIN/clustering/data-planes | jq
{
  "data": [],  # Empty!
  "next": null
}
```

**Possible Causes & Solutions:**

#### Cause A: Missing `KONG_CLUSTER_MTLS` on Data Plane

Both Control Plane and Data Plane MUST have `KONG_CLUSTER_MTLS=shared`.

```bash
# Check Data Plane environment variables
aws ecs describe-task-definition \
  --task-definition sbxservice-dev-kong \
  --query 'taskDefinition.containerDefinitions[0].environment[?name==`KONG_CLUSTER_MTLS`]'
```

**Fix:**
Add to Data Plane environment:
```hcl
{
  name  = "KONG_CLUSTER_MTLS"
  value = "shared"
}
```

#### Cause B: Certificate Issues

Kong Hybrid Mode requires:
- CN (Common Name) = `kong_clustering` (exact, case-sensitive)
- Same certificate on both CP and DP
- Valid certificate (not expired)

```bash
# Check certificate in Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id sbxservice-dev-kong-cluster-cert \
  --query SecretString \
  --output text | openssl x509 -noout -subject
```

**Expected:** `subject=CN = kong_clustering`

**Fix if wrong:**
```bash
# Regenerate certificates
cd terraform
terraform taint 'module.ecs.tls_private_key.kong_cluster[0]'
terraform taint 'module.ecs.tls_self_signed_cert.kong_cluster[0]'
terraform apply

# Force redeploy services
aws ecs update-service --cluster sbxservice-dev-cluster \
  --service sbxservice-dev-kong-cp-service --force-new-deployment
aws ecs update-service --cluster sbxservice-dev-cluster \
  --service sbxservice-dev-kong-service --force-new-deployment
```

#### Cause C: Network Connectivity

Data Plane must reach Control Plane on ports 8005 and 8006 via Cloud Map.

```bash
# Check if CP is registered in Cloud Map
aws servicediscovery discover-instances \
  --namespace-name sbxservice.dev.local \
  --service-name kong-cp

# Check Data Plane logs for connection errors
aws logs tail /ecs/sbxservice-dev-kong --since 5m | grep -i "cluster\|connection"
```

**Fix:**
- Verify security groups allow traffic from DP to CP on ports 8005, 8006
- Verify Cloud Map service registration
- Check VPC DNS resolution is enabled

---

### Issue 3: Routes Not Working

**Symptoms:**
```bash
$ curl $ALB_URL/sbx/api/hello
{"message":"no Route matched with those values"}
```

**Diagnosis & Fix:**

#### Step 1: Verify Route Exists

```bash
curl -s $KONG_ADMIN/routes | jq '.data[] | {name, paths, service}'
```

**Fix:** Create route if missing (see [Kong Admin API Reference](kong_admin_api_reference.md))

#### Step 2: Check Service Configuration

```bash
curl -s $KONG_ADMIN/services/hello-service | jq '{name, host, port, path}'
```

**Common issues:**
- `host` must match upstream name or backend hostname
- `port` should be 80 when using upstream (not backend's 8080)
- `path` prefix if needed

**Fix:**
```bash
curl -X PATCH $KONG_ADMIN/services/hello-service \
  -d "host=hello-upstream" \
  -d "port=80"
```

#### Step 3: Verify Data Plane is Synced

```bash
# Check DP is connected and has latest config
curl -s $KONG_ADMIN/clustering/data-planes | jq '.data[] | {hostname, last_seen, config_hash}'
```

`last_seen` should be within last 30 seconds.

**Fix if stale:**
```bash
aws ecs update-service --cluster sbxservice-dev-cluster \
  --service sbxservice-dev-kong-service --force-new-deployment
```

---

## Health Check Issues

### ⚠️ CRITICAL: Hybrid Mode Health Check Limitation

**In Kong Hybrid Mode, the Control Plane Admin API DOES NOT show health check status.**

- ❌ **Doesn't work**: `curl $KONG_ADMIN/upstreams/{upstream}/health`
- ✅ **Works**: Query Data Plane Status API (port 8100) or verify via behavioral testing

**Reference**: [Kong Health Check in Hybrid Mode](https://surf-ocarina-381.notion.site/Health-Check-in-Hybrid-Mode-2dbf18557a31807cade5c06c24b0928e)

---

### Issue 4: Cannot See Health Check Status

**Symptom:**
```bash
$ curl $KONG_ADMIN/upstreams/hello-upstream/health | jq
{
  "data": [{
    "target": "backend:8080",
    "weight": 100
    # ❌ No "health" field
    # ❌ No "data.addresses" field
  }]
}
```

**Root Cause:**
In Hybrid Mode, health checks run on Data Planes, but Control Plane Admin API doesn't aggregate health data. This is by design, not a bug.

**Solution Options:**

#### Option 1: Query Data Plane Status API ✅

```bash
# Get Data Plane task IP
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

# Query Status API
curl http://$TASK_IP:8100/status | jq
```

#### Option 2: Verify Through Behavioral Testing ✅

This is the most practical approach:

```bash
# Test 1: Normal traffic works
for i in {1..5}; do
  curl -s $ALB_URL/sbx/api/hello -w "Status: %{http_code}\n"
done

# Test 2: Stop one backend task
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

# Test 3: Traffic still works (routes to healthy tasks only)
for i in {1..10}; do
  curl -s $ALB_URL/sbx/api/hello -w "Status: %{http_code}\n"
done

# ✅ If all succeed = health checks are working!
```

#### Option 3: Check Data Plane Logs ✅

```bash
aws logs tail /ecs/sbxservice-dev-kong --since 5m | grep -i health

# Look for:
# [healthcheck] (hello-upstream) target marked as 'healthy'
# [healthcheck] (hello-upstream) probing target ...
```

---

### Issue 5: Health Checks Not Configured

**Symptom:**
Health checks aren't running (no logs, no circuit breaker behavior).

**Diagnosis:**

```bash
# Check if health checks are configured
curl -s $KONG_ADMIN/upstreams/hello-upstream | jq '.healthchecks'
```

**Expected** (configured):
```json
{
  "active": {
    "healthy": {
      "interval": 5,  # Non-zero values
      "successes": 2
    }
  }
}
```

**If all values are 0** → Health checks NOT configured.

**Fix:**

```bash
curl -X PATCH $KONG_ADMIN/upstreams/hello-upstream \
  -H "Content-Type: application/json" \
  -d '{
    "healthchecks": {
      "active": {
        "type": "http",
        "http_path": "/actuator/health",
        "timeout": 1,
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
          "successes": 3
        },
        "unhealthy": {
          "http_failures": 3
        }
      }
    }
  }'
```

Wait 15-20 seconds for health checks to initialize.

---

### Issue 6: Health Endpoint Returns Non-200

**Symptom:**
Health checks configured but marking targets as unhealthy.

**Diagnosis:**

```bash
# Test health endpoint directly
curl -I http://backend.example.com:8080/actuator/health

# Check what status code it returns
```

**Fix:**

If your health endpoint returns 204 or other status:

```bash
curl -X PATCH $KONG_ADMIN/upstreams/hello-upstream \
  -H "Content-Type: application/json" \
  -d '{
    "healthchecks": {
      "active": {
        "healthy": {
          "http_statuses": [200, 201, 204, 302]  # Add your status code
        }
      }
    }
  }'
```

---

## Hybrid Mode Specific Issues

### Issue 7: SSL Handshake Failed - Certificate Host Mismatch

**Symptom:**
```
[warn] [lua] data_plane.lua:156: communicate(): [clustering] connection to control plane 
wss://kong-cp.sbxservice.dev.local:8005/... broken: ssl handshake failed: 
certificate host mismatch
```

**Root Cause:**
Certificate Common Name (CN) is not `kong_clustering`.

**Fix:**

Check certificate CN:
```bash
aws secretsmanager get-secret-value \
  --secret-id sbxservice-dev-kong-cluster-cert \
  --query SecretString \
  --output text | openssl x509 -noout -subject
```

**Must show:** `subject=CN = kong_clustering`

If wrong, regenerate:
```bash
cd terraform
terraform taint 'module.ecs.tls_self_signed_cert.kong_cluster[0]'
terraform apply

# Redeploy services
aws ecs update-service --cluster sbxservice-dev-cluster \
  --service sbxservice-dev-kong-cp-service --force-new-deployment
aws ecs update-service --cluster sbxservice-dev-cluster \
  --service sbxservice-dev-kong-service --force-new-deployment
```

---

### Issue 8: Kong Manager GUI Timeout

**Symptom:**
Kong Manager OSS (port 8002) opens but times out when creating services/routes.

**Root Cause:**
Kong Manager GUI needs to call Admin API (port 8001) but doesn't know the URL.

**Fix:**

Verify Control Plane environment variables:
```bash
aws ecs describe-task-definition \
  --task-definition sbxservice-dev-kong-cp \
  --query 'taskDefinition.containerDefinitions[0].environment[?contains(name, `GUI`)]'
```

**Required:**
```hcl
{
  name  = "KONG_ADMIN_GUI_URL"
  value = "http://<ALB-DNS>:8002"
},
{
  name  = "KONG_ADMIN_GUI_API_URL"
  value = "http://<ALB-DNS>:8001"
}
```

Also ensure ALB has listener on port 8001.

---

## Database Issues

### Issue 9: Database Connection Errors

**Symptoms:**
- Kong CP logs show "could not connect to postgres"
- CP container keeps restarting

**Diagnosis:**

```bash
# Check RDS status
aws rds describe-db-instances \
  --db-instance-identifier sbxservice-dev-kong-db

# Check security group allows Kong CP
aws ec2 describe-security-groups \
  --group-ids <database-sg-id> \
  --query 'SecurityGroups[0].IpPermissions'

# Test connection from Kong CP task
# (requires exec into task or use test container)
```

**Fix:**

1. **Security Group**: Allow port 5432 from Kong CP security group
2. **Credentials**: Verify in Secrets Manager
3. **Endpoint**: Verify `KONG_PG_HOST` matches RDS endpoint

---

### Issue 10: Database Migration Errors

**Symptoms:**
- Kong CP logs show migration errors
- Tables not created

**Common Causes:**

1. **User lacks permissions**
2. **Version incompatibility**
3. **Corrupted migration state**

**Fix:**

```bash
# Check migrations
aws logs tail /ecs/sbxservice-dev-kong-cp --since 10m | grep -i migration

# If stuck, manually connect and check
psql -h <rds-endpoint> -U kong -d kong -c "\dt"
```

---

## Network and Connectivity

### Issue 11: 502 Bad Gateway

**Symptom:**
```bash
$ curl $ALB_URL/sbx/api/hello
502 Bad Gateway
```

**Diagnosis:**

```bash
# Check if backend is reachable
curl -v http://backend.sbxservice.dev.local:8080/hello

# Check Kong DP logs
aws logs tail /ecs/sbxservice-dev-kong --since 5m | grep -i "503\|502\|upstream"
```

**Common Causes:**
1. Backend not running
2. Wrong backend port in service configuration
3. Network connectivity issue
4. All targets marked unhealthy

**Fix:**

```bash
# Verify service configuration
curl -s $KONG_ADMIN/services/hello-service | jq '{host, port, path}'

# Check if backend is running
aws ecs describe-services --cluster sbxservice-dev-cluster \
  --services sbxservice-dev-service \
  --query 'services[0].runningCount'
```

---

### Issue 12: Timeout Errors

**Symptom:**
```
upstream request timeout
```

**Fix:**

Increase service timeouts:
```bash
curl -X PATCH $KONG_ADMIN/services/hello-service \
  -d "connect_timeout=60000" \
  -d "read_timeout=60000" \
  -d "write_timeout=60000"
```

---

## Performance Issues

### Issue 13: High Latency

**Diagnosis:**

```bash
# Check Kong DP CPU/Memory
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=sbxservice-dev-kong-service \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

**Solutions:**
1. Scale Data Planes: Increase `kong_app_count`
2. Optimize backend: Check backend response time
3. Enable caching: Use `proxy-cache` plugin
4. Review plugins: Some plugins add latency

---

## Debugging Commands

### Comprehensive Health Check Script

```bash
#!/bin/bash
echo "=== Kong Gateway Comprehensive Diagnostics ==="
echo ""

# 1. Control Plane
echo "1. Control Plane Status:"
curl -s $KONG_ADMIN/status | jq -r '
  "Server: \(.server)",
  "Database: \(.database.reachable)"
'

# 2. Data Planes
echo "2. Connected Data Planes:"
curl -s $KONG_ADMIN/clustering/data-planes | jq -r '
  "Total: \(.data | length)",
  (.data[] | "  - \(.hostname) (last_seen: \(.last_seen))")
'

# 3. Services
echo "3. Services:"
curl -s $KONG_ADMIN/services | jq -r '
  "Total: \(.data | length)",
  (.data[] | "  - \(.name): \(.host):\(.port)")
'

# 4. Routes
echo "4. Routes:"
curl -s $KONG_ADMIN/routes | jq -r '
  "Total: \(.data | length)",
  (.data[] | "  - \(.name): \(.paths | join(", "))")
'

# 5. ECS Services
echo "5. ECS Services Status:"
for svc in sbxservice-dev-kong-cp-service sbxservice-dev-kong-service sbxservice-dev-service; do
  COUNT=$(aws ecs describe-services \
    --cluster sbxservice-dev-cluster \
    --services $svc \
    --query 'services[0].runningCount' \
    --output text)
  echo "  - $svc: $COUNT running"
done

# 6. Test API
echo "6. API Test:"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" $ALB_URL/sbx/api/hello)
echo "  - $ALB_URL/sbx/api/hello: $STATUS"

echo ""
echo "=== Diagnostics Complete ==="
```

### Force Regenerate Everything

```bash
#!/bin/bash
# Nuclear option: Regenerate certificates and redeploy everything

cd terraform

# Taint certificates
terraform taint 'module.ecs.tls_private_key.kong_cluster[0]'
terraform taint 'module.ecs.tls_self_signed_cert.kong_cluster[0]'
terraform taint 'module.ecs.aws_secretsmanager_secret_version.kong_cluster_cert[0]'
terraform taint 'module.ecs.aws_secretsmanager_secret_version.kong_cluster_key[0]'

# Apply
terraform apply -auto-approve

# Force redeploy all Kong services
aws ecs update-service --cluster sbxservice-dev-cluster \
  --service sbxservice-dev-kong-cp-service --force-new-deployment
  
aws ecs update-service --cluster sbxservice-dev-cluster \
  --service sbxservice-dev-kong-service --force-new-deployment

echo "Waiting 60 seconds for services to stabilize..."
sleep 60

# Check status
curl -s $KONG_ADMIN/status
curl -s $KONG_ADMIN/clustering/data-planes | jq '.data | length'
```

---

## Common Error Messages Reference

| Error Message | Likely Cause | Fix |
|---------------|--------------|-----|
| `no Route matched` | Route not configured or wrong path | Check routes configuration |
| `An invalid response was received from the upstream server` | Backend unreachable or wrong port | Check service host/port |
| `ssl handshake failed: certificate host mismatch` | Certificate CN not `kong_clustering` | Regenerate certificate |
| `connection refused` | Backend not running | Start backend service |
| `could not connect to postgres` | Database unreachable | Check DB status and security groups |
| `no Data Planes connected` | Missing `KONG_CLUSTER_MTLS` or cert issue | Check DP environment variables |
| `upstream request timeout` | Backend slow or timeouts too short | Increase service timeouts |

---

## Getting Help

### Check Logs

```bash
# Kong Control Plane
aws logs tail /ecs/sbxservice-dev-kong-cp --since 30m --follow

# Kong Data Plane
aws logs tail /ecs/sbxservice-dev-kong --since 30m --follow

# Backend Service
aws logs tail /ecs/sbxservice-dev-service --since 30m --follow
```

### Useful Resources

- [Kong Gateway Guide](kong_gateway_guide.md) - Setup and configuration
- [Kong Admin API Reference](kong_admin_api_reference.md) - Complete API reference
- [Kong Testing Guide](kong_testing_guide.md) - Testing procedures
- [Kong Official Docs](https://docs.konghq.com/gateway/latest/)
- [Kong Community Forum](https://discuss.konghq.com/)

---

## Summary

Most Kong issues fall into these categories:
1. **Connectivity**: Data Planes not connecting to Control Plane (certificates, mTLS, network)
2. **Configuration**: Routes/services misconfigured
3. **Health Checks**: Not visible in Hybrid Mode (query DP Status API instead)
4. **Database**: Connection or migration issues
5. **Network**: Backend unreachable, wrong ports

**Pro Tips:**
- Always check Data Plane logs first
- Verify Data Planes are connected before troubleshooting routes
- Remember: Health checks work but aren't visible via CP Admin API in Hybrid Mode
- Use behavioral testing to verify health checks
- Force redeploy services to pick up new configuration/certificates

For complex issues, start with the comprehensive health check script above!

