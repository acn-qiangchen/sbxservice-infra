# Kong Hybrid Mode Troubleshooting Guide

This document covers common issues and solutions when setting up Kong Gateway in Hybrid Mode with a self-hosted Control Plane and Data Planes on AWS ECS.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Kong Hybrid Mode                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────┐         ┌─────────────────────┐        │
│  │   Control Plane     │◄───────►│    Data Plane       │        │
│  │   (kong-cp)         │  mTLS   │    (kong-gateway)   │        │
│  │                     │         │                     │        │
│  │  Ports:             │         │  Ports:             │        │
│  │  - 8001: Admin API  │         │  - 8000: Proxy      │        │
│  │  - 8002: Admin GUI  │         │  - 8100: Status     │        │
│  │  - 8005: Cluster    │         │                     │        │
│  │  - 8006: Telemetry  │         │                     │        │
│  └─────────────────────┘         └─────────────────────┘        │
│           │                               │                      │
│           ▼                               │                      │
│  ┌─────────────────────┐                  │                      │
│  │   PostgreSQL (RDS)  │                  │                      │
│  └─────────────────────┘                  │                      │
│                                           ▼                      │
│                              ┌─────────────────────┐            │
│                              │   Backend Services  │            │
│                              │   (hello-service)   │            │
│                              └─────────────────────┘            │
└─────────────────────────────────────────────────────────────────┘
```

## Common Issues and Solutions

### Issue 0: Cannot See Health Check Status via Admin API

**Symptom:**
```bash
$ curl http://<ALB>:8001/upstreams/hello-upstream/health | jq
# Shows no "health" field, or shows stale data
```

**Root Cause:**
In Kong Hybrid Mode, health checks run on Data Planes, but the Control Plane Admin API **does NOT show real-time health status**. This is a known limitation, not a bug.

**Reference:** [Kong Health Check in Hybrid Mode](https://surf-ocarina-381.notion.site/Health-Check-in-Hybrid-Mode-2dbf18557a31807cade5c06c24b0928e)

**Solution:**

Health checks ARE working (they affect traffic routing), but you can't see the status via Control Plane Admin API.

**Option 1: Query Data Plane Status API (Port 8100)**

```bash
# Access Data Plane via service discovery
curl http://kong-gateway.sbxservice.dev.local:8100/status | jq

# Or get Data Plane task IP
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

**Option 2: Verify Through Behavioral Testing**

```bash
# Stop a backend task
aws ecs stop-task \
  --cluster sbxservice-dev-cluster \
  --task $(aws ecs list-tasks \
    --cluster sbxservice-dev-cluster \
    --service-name sbxservice-dev-service \
    --query 'taskArns[0]' \
    --output text)

# Wait for health checks to detect failure
sleep 20

# Send traffic - should still succeed (routes to healthy tasks only)
for i in {1..10}; do
  curl $ALB_URL/sbx/api/hello -w "Status: %{http_code}\n"
done

# All requests succeed = health checks working! ✅
```

**Option 3: Check Data Plane Logs**

```bash
aws logs tail /ecs/sbxservice-dev-kong --since 5m | grep -i health

# Look for:
# [healthcheck] (hello-upstream) target marked as 'healthy'
```

---

### Issue 1: Data Plane Not Connected to Control Plane

**Symptom:**
```bash
$ curl http://<ALB>:8001/clustering/data-planes
{"next":null,"data":[]}  # Empty = no DP connected
```

**Possible Causes:**

1. **Missing `KONG_CLUSTER_MTLS` on Data Plane**
   
   Both Control Plane and Data Plane must have the same `KONG_CLUSTER_MTLS` setting.

   ```hcl
   # Control Plane
   {
     name  = "KONG_CLUSTER_MTLS"
     value = "shared"
   }
   
   # Data Plane - MUST also have this!
   {
     name  = "KONG_CLUSTER_MTLS"
     value = "shared"
   }
   ```

2. **Network connectivity issues**
   
   Ensure the Data Plane can reach the Control Plane on ports 8005 (cluster) and 8006 (telemetry).
   
   Check Cloud Map service discovery:
   ```bash
   # DP connects to CP via:
   kong-cp.sbxservice.dev.local:8005
   kong-cp.sbxservice.dev.local:8006
   ```

---

### Issue 2: SSL Handshake Failed - Certificate Host Mismatch

**Symptom:**
```
[warn] [lua] data_plane.lua:156: communicate(): [clustering] connection to control plane 
wss://kong-cp.sbxservice.dev.local:8005/... broken: ssl handshake failed: 
certificate host mismatch (retrying after 6 seconds)
```

**Root Cause:**
The certificate's Subject Alternative Names (SANs) don't include the hostname used by the Data Plane.

**Solution:**
When using `cluster_mtls=shared`, Kong verifies the certificate's **Common Name (CN)**, not SANs. The CN must be exactly `kong_clustering`.

```hcl
resource "tls_self_signed_cert" "kong_cluster" {
  subject {
    # IMPORTANT: Kong hybrid mode requires CN to be exactly "kong_clustering"
    common_name  = "kong_clustering"  # ✅ Correct
    # common_name  = "kong-cluster"   # ❌ Wrong!
    organization = var.project_name
  }
  # ... rest of config
}
```

---

### Issue 3: SSL Handshake Failed - Self-Signed Certificate

**Symptom:**
```
[warn] [lua] data_plane.lua:156: communicate(): [clustering] connection to control plane 
wss://kong-cp.sbxservice.dev.local:8005/... broken: ssl handshake failed: 
18: self-signed certificate (retrying after 10 seconds)
```

**Root Cause:**
The certificate Common Name (CN) is not set to `kong_clustering`.

**Solution:**
Per [Kong's Hybrid Mode documentation](https://docs.konghq.com/gateway/latest/production/deployment-topologies/hybrid-mode/), when using `cluster_mtls=shared`:

1. **CN must be `kong_clustering`**
2. **Both CP and DP must use the same certificate and key**
3. **Both must have `KONG_CLUSTER_MTLS=shared`**

```hcl
# Correct certificate configuration
resource "tls_self_signed_cert" "kong_cluster" {
  count           = var.kong_enabled ? 1 : 0
  private_key_pem = tls_private_key.kong_cluster[0].private_key_pem

  subject {
    common_name  = "kong_clustering"  # REQUIRED for hybrid mode
    organization = var.project_name
  }

  validity_period_hours = 87600 # 10 years

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}
```

---

### Issue 4: Kong Manager GUI Timeout When Creating Entities

**Symptom:**
When using Kong Manager OSS GUI (port 8002), creating upstreams, services, or routes times out with errors like:
```
/schemas/upstreams/validate - timeout
```

**Root Cause:**
Kong Manager GUI needs to call the Admin API (port 8001), but it doesn't know the correct URL.

**Solution:**
Set the `KONG_ADMIN_GUI_API_URL` environment variable on the Control Plane:

```hcl
# Control Plane environment variables
{
  name  = "KONG_ADMIN_GUI_URL"
  value = "http://${aws_lb.main.dns_name}:8002"
},
{
  name  = "KONG_ADMIN_GUI_API_URL"
  value = "http://${aws_lb.main.dns_name}:8001"
},
```

Also ensure the ALB has a listener on port 8001:

```hcl
resource "aws_lb_listener" "kong_admin_api" {
  count             = var.kong_control_plane_enabled ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = 8001
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.kong_admin[0].arn
  }
}
```

---

### Issue 5: Route Not Found (No Route Matched)

**Symptom:**
```bash
$ curl http://<ALB>/root
{"message":"no Route matched with those values"}
```

**Possible Causes:**

1. **Data Plane not synced with Control Plane**
   
   Check if DP is connected:
   ```bash
   curl http://<ALB>:8001/clustering/data-planes
   ```

2. **Service configuration issues**
   
   Verify service configuration:
   ```bash
   curl http://<ALB>:8001/services/hello-service
   ```
   
   Check that:
   - `host` matches the upstream name exactly
   - `port` matches the backend port (e.g., 8080, not 80)
   - `path` is set correctly (e.g., `/api/hello`)

3. **Route protocol mismatch**
   
   Check route protocols:
   ```bash
   curl http://<ALB>:8001/routes
   ```
   
   Ensure `protocols` includes `http` if accessing via HTTP.

---

## Debugging Commands

### Check Control Plane Status

```bash
# Admin API health
curl http://<ALB>:8001/status

# List all services
curl http://<ALB>:8001/services

# List all routes
curl http://<ALB>:8001/routes

# List all upstreams
curl http://<ALB>:8001/upstreams

# Check connected data planes
curl http://<ALB>:8001/clustering/data-planes
```

### Check ECS Logs

```bash
# Kong Control Plane logs
aws logs tail /ecs/sbxservice-dev-kong-cp --since 10m --follow

# Kong Data Plane logs
aws logs tail /ecs/sbxservice-dev-kong --since 10m --follow
```

### Force Redeploy Services

```bash
# Redeploy Control Plane
aws ecs update-service --cluster sbxservice-dev-cluster \
  --service sbxservice-dev-kong-cp-service --force-new-deployment

# Redeploy Data Plane
aws ecs update-service --cluster sbxservice-dev-cluster \
  --service sbxservice-dev-kong-service --force-new-deployment
```

### Regenerate Certificates

If you need to regenerate certificates after fixing the configuration:

```bash
cd terraform

# Delete old secrets
aws secretsmanager delete-secret --secret-id sbxservice-dev-kong-cluster-cert --force-delete-without-recovery
aws secretsmanager delete-secret --secret-id sbxservice-dev-kong-cluster-key --force-delete-without-recovery

# Taint Terraform resources
terraform taint 'module.ecs.tls_private_key.kong_cluster[0]'
terraform taint 'module.ecs.tls_self_signed_cert.kong_cluster[0]'

# Apply changes
terraform apply

# Force redeploy both services
aws ecs update-service --cluster sbxservice-dev-cluster \
  --service sbxservice-dev-kong-cp-service --force-new-deployment
aws ecs update-service --cluster sbxservice-dev-cluster \
  --service sbxservice-dev-kong-service --force-new-deployment
```

---

## Required Environment Variables

### Control Plane

| Variable | Value | Description |
|----------|-------|-------------|
| `KONG_ROLE` | `control_plane` | Sets node as CP |
| `KONG_DATABASE` | `postgres` | Database type |
| `KONG_PG_HOST` | RDS endpoint | PostgreSQL host |
| `KONG_PG_PORT` | `5432` | PostgreSQL port |
| `KONG_PG_USER` | `kong` | PostgreSQL user |
| `KONG_PG_DATABASE` | `kong` | PostgreSQL database |
| `KONG_PG_PASSWORD` | (secret) | PostgreSQL password |
| `KONG_ADMIN_LISTEN` | `0.0.0.0:8001` | Admin API listen address |
| `KONG_ADMIN_GUI_LISTEN` | `0.0.0.0:8002` | Admin GUI listen address |
| `KONG_ADMIN_GUI_URL` | `http://<ALB>:8002` | External GUI URL |
| `KONG_ADMIN_GUI_API_URL` | `http://<ALB>:8001` | External Admin API URL |
| `KONG_CLUSTER_LISTEN` | `0.0.0.0:8005` | Cluster listen address |
| `KONG_CLUSTER_TELEMETRY_LISTEN` | `0.0.0.0:8006` | Telemetry listen address |
| `KONG_CLUSTER_MTLS` | `shared` | mTLS mode |
| `KONG_CLUSTER_CERT` | (secret) | Cluster certificate |
| `KONG_CLUSTER_CERT_KEY` | (secret) | Cluster private key |

### Data Plane

| Variable | Value | Description |
|----------|-------|-------------|
| `KONG_ROLE` | `data_plane` | Sets node as DP |
| `KONG_DATABASE` | `off` | No local database |
| `KONG_CLUSTER_CONTROL_PLANE` | `kong-cp.<namespace>:8005` | CP cluster endpoint |
| `KONG_CLUSTER_TELEMETRY_ENDPOINT` | `kong-cp.<namespace>:8006` | CP telemetry endpoint |
| `KONG_CLUSTER_MTLS` | `shared` | mTLS mode (must match CP) |
| `KONG_CLUSTER_CERT` | (secret) | Cluster certificate (same as CP) |
| `KONG_CLUSTER_CERT_KEY` | (secret) | Cluster private key (same as CP) |
| `KONG_STATUS_LISTEN` | `0.0.0.0:8100` | Status API for health checks |

---

## References

- [Kong Hybrid Mode Documentation](https://docs.konghq.com/gateway/latest/production/deployment-topologies/hybrid-mode/)
- [Kong Hybrid Mode Setup](https://docs.konghq.com/gateway/latest/production/deployment-topologies/hybrid-mode/setup/)
- [Kong Cluster Certificate Requirements](https://docs.konghq.com/gateway/latest/production/deployment-topologies/hybrid-mode/setup/#generate-a-certificate-key-pair)

