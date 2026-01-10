# Kong Admin API Command Book

This document provides a comprehensive guide to managing Kong Gateway configuration using the REST Admin API.

## Architecture Context

```
┌─────────────────────────────────────────────────────────────────┐
│                     Request Flow                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Client Request                                                  │
│       │                                                          │
│       ▼                                                          │
│  ┌─────────────────────┐                                        │
│  │  Data Plane (8000)  │                                        │
│  │  (Proxy)            │                                        │
│  └──────────┬──────────┘                                        │
│             │                                                    │
│             │ Route Match: /hello                                │
│             ▼                                                    │
│  ┌─────────────────────┐                                        │
│  │  Service            │                                        │
│  │  (hello-service)    │                                        │
│  └──────────┬──────────┘                                        │
│             │                                                    │
│             │ Load Balance                                       │
│             ▼                                                    │
│  ┌─────────────────────┐                                        │
│  │  Upstream           │                                        │
│  │  (hello-upstream)   │                                        │
│  └──────────┬──────────┘                                        │
│             │                                                    │
│             │ Forward to Target                                 │
│             ▼                                                    │
│  ┌─────────────────────┐                                        │
│  │  Target             │                                        │
│  │  (hello backend)    │                                        │
│  └─────────────────────┘                                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

```bash
# Set your Kong Admin API endpoint
export KONG_ADMIN="http://sbxservice-dev-alb-XXXXXX.us-east-1.elb.amazonaws.com:8001"

# Or get it from Terraform output
cd terraform
export KONG_ADMIN=$(terraform output -raw kong_admin_api_endpoint)

# Verify connection
curl -s $KONG_ADMIN/status | jq
```

## Entity Hierarchy

Kong entities have the following hierarchy:

```
Upstream (Load Balancer Group)
  └── Target (Backend Server Instance)
  
Service (API Backend Definition)
  └── Points to: Upstream OR Direct Host
  
Route (URL Mapping)
  └── Attached to: Service
  
Plugin (Feature/Policy)
  └── Can be attached to: Service, Route, or Global
```

---

## Complete Example: Hello Service

This example sets up the `hello-service` accessible at `http://sbxservice.sbxservice.dev.local:8080`.

### Step 1: Create Upstream

Create a load balancer group for hello-service:

```bash
curl -X POST $KONG_ADMIN/upstreams \
  -H "Content-Type: application/json" \
  -d '{
    "name": "hello-upstream",
    "algorithm": "round-robin",
    "slots": 1000,
    "healthchecks": {
      "passive": {
        "healthy": {
          "successes": 5
        },
        "unhealthy": {
          "http_failures": 5,
          "timeouts": 3
        }
      }
    }
  }' | jq
```

**Response:**
```json
{
  "id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "name": "hello-upstream",
  "algorithm": "round-robin",
  "slots": 1000,
  "created_at": 1234567890
}
```

### Step 2: Add Target to Upstream

Add the actual backend server to the upstream:

```bash
curl -X POST $KONG_ADMIN/upstreams/hello-upstream/targets \
  -H "Content-Type: application/json" \
  -d '{
    "target": "sbxservice.sbxservice.dev.local:8080",
    "weight": 100
  }' | jq
```

**Response:**
```json
{
  "id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "target": "sbxservice.sbxservice.dev.local:8080",
  "weight": 100,
  "upstream": {
    "id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  },
  "created_at": 1234567890
}
```

### Step 3: Create Service

Create a service that points to the upstream:

```bash
curl -X POST $KONG_ADMIN/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "hello-service",
    "host": "hello-upstream",
    "port": 80,
    "protocol": "http",
    "path": "/",
    "retries": 5,
    "connect_timeout": 60000,
    "write_timeout": 60000,
    "read_timeout": 60000
  }' | jq
```

**Important Notes:**
- `"host": "hello-upstream"` - This references the upstream name
- `"port": 80` - This is the Kong-side port (not the target's 8080)
- `"path": "/"` - Base path to append to upstream requests

**Response:**
```json
{
  "id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "name": "hello-service",
  "protocol": "http",
  "host": "hello-upstream",
  "port": 80,
  "path": "/",
  "created_at": 1234567890
}
```

### Step 4: Create Route

Create a route to expose the service:

```bash
curl -X POST $KONG_ADMIN/services/hello-service/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "hello-route",
    "paths": ["/sbx"],
    "methods": ["GET", "POST", "PUT", "DELETE", "PATCH"],
    "strip_path": true,
    "preserve_host": false
  }' | jq
```

**Route Options:**
- `"strip_path": true` - Remove `/sbx` before forwarding to backend
- `"strip_path": false` - Keep `/sbx` in the request to backend
- `"preserve_host": false` - Use upstream host (recommended)
- `"preserve_host": true` - Keep original client Host header

**Response:**
```json
{
  "id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "name": "hello-route",
  "paths": ["/sbx"],
  "methods": ["GET", "POST", "PUT", "DELETE", "PATCH"],
  "service": {
    "id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  },
  "created_at": 1234567890
}
```

### Step 5: Test the Setup

```bash
# Get the Data Plane (proxy) endpoint
export ALB_URL="http://sbxservice-dev-alb-XXXXXX.us-east-1.elb.amazonaws.com"

# Test the route
curl -v $ALB_URL/sbx/api/hello

# Expected: Request forwarded to hello-service backend
```

**Request Flow:**
```
Client → ALB:80/sbx → Kong DP:8000 → hello-service → upstream → sbxservice.sbxservice.dev.local:8080
```

---

## General Template for Any Service

### Variables

```bash
# Define your service variables
SERVICE_NAME="my-service"
UPSTREAM_NAME="my-upstream"
ROUTE_NAME="my-route"
BACKEND_HOST="my-backend.example.com"
BACKEND_PORT="8080"
ROUTE_PATH="/api"
```

### 1. Create Upstream

```bash
curl -X POST $KONG_ADMIN/upstreams \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"${UPSTREAM_NAME}\",
    \"algorithm\": \"round-robin\"
  }" | jq
```

### 2. Add Target

```bash
curl -X POST $KONG_ADMIN/upstreams/${UPSTREAM_NAME}/targets \
  -H "Content-Type: application/json" \
  -d "{
    \"target\": \"${BACKEND_HOST}:${BACKEND_PORT}\",
    \"weight\": 100
  }" | jq
```

### 3. Create Service

```bash
curl -X POST $KONG_ADMIN/services \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"${SERVICE_NAME}\",
    \"host\": \"${UPSTREAM_NAME}\",
    \"port\": 80,
    \"protocol\": \"http\"
  }" | jq
```

### 4. Create Route

```bash
curl -X POST $KONG_ADMIN/services/${SERVICE_NAME}/routes \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"${ROUTE_NAME}\",
    \"paths\": [\"${ROUTE_PATH}\"],
    \"strip_path\": true
  }" | jq
```

---

## Common Operations

### List All Entities

```bash
# List upstreams
curl -s $KONG_ADMIN/upstreams | jq '.data[] | {id, name}'

# List services
curl -s $KONG_ADMIN/services | jq '.data[] | {id, name, host, port}'

# List routes
curl -s $KONG_ADMIN/routes | jq '.data[] | {id, name, paths, service: .service.id}'

# List targets for an upstream
curl -s $KONG_ADMIN/upstreams/hello-upstream/targets | jq '.data[] | {target, weight}'
```

### Get Specific Entity

```bash
# Get upstream by name
curl -s $KONG_ADMIN/upstreams/hello-upstream | jq

# Get service by name
curl -s $KONG_ADMIN/services/hello-service | jq

# Get route by name
curl -s $KONG_ADMIN/routes/hello-route | jq
```

### Update Entities

```bash
# Update service timeouts
curl -X PATCH $KONG_ADMIN/services/hello-service \
  -H "Content-Type: application/json" \
  -d '{
    "connect_timeout": 30000,
    "read_timeout": 30000
  }' | jq

# Update route paths
curl -X PATCH $KONG_ADMIN/routes/hello-route \
  -H "Content-Type: application/json" \
  -d '{
    "paths": ["/hello", "/hello-v2"]
  }' | jq

# Update target weight
curl -X PATCH $KONG_ADMIN/upstreams/hello-upstream/targets/TARGET_ID \
  -H "Content-Type: application/json" \
  -d '{
    "weight": 50
  }' | jq
```

### Delete Entities

```bash
# Delete route (delete first - most dependent)
curl -X DELETE $KONG_ADMIN/routes/hello-route

# Delete service
curl -X DELETE $KONG_ADMIN/services/hello-service

# Delete target
curl -X DELETE $KONG_ADMIN/upstreams/hello-upstream/targets/TARGET_ID

# Delete upstream (delete last - least dependent)
curl -X DELETE $KONG_ADMIN/upstreams/hello-upstream
```

**Important:** Delete in reverse order of dependency to avoid errors.

---

## Advanced Upstream Configuration

### Multiple Targets (Load Balancing)

```bash
# Add multiple backend servers
curl -X POST $KONG_ADMIN/upstreams/hello-upstream/targets \
  -d "target=backend1.example.com:8080" \
  -d "weight=100"

curl -X POST $KONG_ADMIN/upstreams/hello-upstream/targets \
  -d "target=backend2.example.com:8080" \
  -d "weight=100"

curl -X POST $KONG_ADMIN/upstreams/hello-upstream/targets \
  -d "target=backend3.example.com:8080" \
  -d "weight=50"  # Less weight = less traffic
```

### Active Health Checks

```bash
curl -X PATCH $KONG_ADMIN/upstreams/hello-upstream \
  -H "Content-Type: application/json" \
  -d '{
    "healthchecks": {
      "active": {
        "type": "http",
        "http_path": "/health",
        "timeout": 1,
        "concurrency": 10,
        "healthy": {
          "interval": 5,
          "successes": 2
        },
        "unhealthy": {
          "interval": 5,
          "http_failures": 3,
          "timeouts": 3
        }
      }
    }
  }' | jq
```

### Passive Health Checks

```bash
curl -X PATCH $KONG_ADMIN/upstreams/hello-upstream \
  -H "Content-Type: application/json" \
  -d '{
    "healthchecks": {
      "passive": {
        "type": "http",
        "healthy": {
          "successes": 5
        },
        "unhealthy": {
          "http_failures": 5,
          "tcp_failures": 2,
          "timeouts": 3
        }
      }
    }
  }' | jq
```

### Check Upstream Health

```bash
# View upstream health status
curl -s $KONG_ADMIN/upstreams/hello-upstream/health | jq

# Sample output:
# {
#   "total": 3,
#   "data": [
#     {
#       "target": "backend1.example.com:8080",
#       "health": "HEALTHY",
#       "weight": 100
#     }
#   ]
# }
```

---

## Route Matching Strategies

### Path-Based Routing

```bash
# Match by path
curl -X POST $KONG_ADMIN/services/hello-service/routes \
  -d "name=hello-api-v1" \
  -d "paths[]=/api/v1/hello" \
  -d "strip_path=true"
```

### Host-Based Routing

```bash
# Match by hostname
curl -X POST $KONG_ADMIN/services/hello-service/routes \
  -d "name=hello-subdomain" \
  -d "hosts[]=api.example.com" \
  -d "paths[]=/hello"
```

### Method-Based Routing

```bash
# Only match specific HTTP methods
curl -X POST $KONG_ADMIN/services/hello-service/routes \
  -d "name=hello-get-only" \
  -d "paths[]=/hello" \
  -d "methods[]=GET"
```

### Header-Based Routing

```bash
# Match by header
curl -X POST $KONG_ADMIN/services/hello-service/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "hello-api-version",
    "paths": ["/hello"],
    "headers": {
      "X-API-Version": ["v1", "v2"]
    }
  }' | jq
```

### Regex Path Matching

```bash
# Use regex for flexible path matching
curl -X POST $KONG_ADMIN/services/hello-service/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "hello-regex",
    "paths": ["~/api/v[0-9]+/hello"]
  }' | jq
```

---

## Adding Plugins

### Rate Limiting

```bash
# Add rate limiting to a service
curl -X POST $KONG_ADMIN/services/hello-service/plugins \
  -d "name=rate-limiting" \
  -d "config.minute=100" \
  -d "config.hour=10000" \
  -d "config.policy=local"
```

### CORS

```bash
# Enable CORS for a route
curl -X POST $KONG_ADMIN/routes/hello-route/plugins \
  -d "name=cors" \
  -d "config.origins=*" \
  -d "config.methods=GET,POST,PUT,DELETE" \
  -d "config.headers=Accept,Content-Type,Authorization" \
  -d "config.credentials=true" \
  -d "config.max_age=3600"
```

### Request Transformation

```bash
# Add custom headers to requests
curl -X POST $KONG_ADMIN/services/hello-service/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "request-transformer",
    "config": {
      "add": {
        "headers": ["X-Service-Name:hello-service"]
      }
    }
  }' | jq
```

### Authentication (Key Auth)

```bash
# Enable key authentication
curl -X POST $KONG_ADMIN/services/hello-service/plugins \
  -d "name=key-auth" \
  -d "config.key_names[]=apikey"

# Create a consumer
curl -X POST $KONG_ADMIN/consumers \
  -d "username=my-app"

# Create an API key for the consumer
curl -X POST $KONG_ADMIN/consumers/my-app/key-auth \
  -d "key=my-secret-api-key-12345"

# Test with authentication
curl -H "apikey: my-secret-api-key-12345" $ALB_URL/sbx/api/hello
```

---

## Verification and Testing

### Check Configuration Sync

```bash
# Verify Data Planes are connected
curl -s $KONG_ADMIN/clustering/data-planes | jq '.data[] | {id, hostname, last_seen, config_hash}'

# Should show connected DPs with recent timestamps
```

### Test End-to-End

```bash
# 1. Check Admin API
curl -s $KONG_ADMIN/status | jq

# 2. List your configuration
curl -s $KONG_ADMIN/services/hello-service | jq
curl -s $KONG_ADMIN/routes/hello-route | jq

# 3. Test through Data Plane proxy
export ALB_URL="http://sbxservice-dev-alb-XXXXXX.us-east-1.elb.amazonaws.com"
curl -v $ALB_URL/sbx/api/hello

# 4. Check upstream health
curl -s $KONG_ADMIN/upstreams/hello-upstream/health | jq
```

### Debugging Failed Requests

```bash
# Enable debug headers
curl -v -H "X-Kong-Debug: 1" $ALB_URL/sbx/api/hello

# Check Kong error logs
aws logs tail /ecs/sbxservice-dev-kong --since 5m --follow

# Check Control Plane logs
aws logs tail /ecs/sbxservice-dev-kong-cp --since 5m --follow
```

---

## Quick Reference Scripts

### Complete Setup Script

```bash
#!/bin/bash
set -e

# Configuration
KONG_ADMIN="http://your-alb:8001"
SERVICE_NAME="hello-service"
UPSTREAM_NAME="hello-upstream"
ROUTE_NAME="hello-route"
BACKEND_TARGET="sbxservice.sbxservice.dev.local:8080"
ROUTE_PATH="/hello"

echo "Creating upstream..."
curl -X POST $KONG_ADMIN/upstreams \
  -d "name=${UPSTREAM_NAME}" \
  -d "algorithm=round-robin"

echo "Adding target..."
curl -X POST $KONG_ADMIN/upstreams/${UPSTREAM_NAME}/targets \
  -d "target=${BACKEND_TARGET}" \
  -d "weight=100"

echo "Creating service..."
curl -X POST $KONG_ADMIN/services \
  -d "name=${SERVICE_NAME}" \
  -d "host=${UPSTREAM_NAME}" \
  -d "port=80"

echo "Creating route..."
curl -X POST $KONG_ADMIN/services/${SERVICE_NAME}/routes \
  -d "name=${ROUTE_NAME}" \
  -d "paths[]=${ROUTE_PATH}" \
  -d "strip_path=true"

echo "Done! Test with: curl http://your-alb${ROUTE_PATH}"
```

### Teardown Script

```bash
#!/bin/bash
set -e

KONG_ADMIN="http://your-alb:8001"
SERVICE_NAME="hello-service"
UPSTREAM_NAME="hello-upstream"
ROUTE_NAME="hello-route"

echo "Deleting route..."
curl -X DELETE $KONG_ADMIN/routes/${ROUTE_NAME}

echo "Deleting service..."
curl -X DELETE $KONG_ADMIN/services/${SERVICE_NAME}

echo "Deleting upstream..."
curl -X DELETE $KONG_ADMIN/upstreams/${UPSTREAM_NAME}

echo "Done!"
```

---

## Common Issues and Solutions

### Issue: Route Not Found

**Symptom:**
```json
{"message":"no Route matched with those values"}
```

**Solutions:**
1. Verify route exists: `curl $KONG_ADMIN/routes/hello-route | jq`
2. Check route path: `curl $KONG_ADMIN/routes | jq '.data[] | {name, paths}'`
3. Verify Data Planes are synced: `curl $KONG_ADMIN/clustering/data-planes | jq`

### Issue: Service Unavailable (502)

**Symptom:**
```json
{"message":"An invalid response was received from the upstream server"}
```

**Solutions:**
1. Check target is reachable: `curl http://sbxservice.sbxservice.dev.local:8080`
2. Verify upstream health: `curl $KONG_ADMIN/upstreams/hello-upstream/health | jq`
3. Check service host matches upstream name: `curl $KONG_ADMIN/services/hello-service | jq .host`

### Issue: Gateway Timeout (504)

**Symptom:**
```json
{"message":"The upstream server is timing out"}
```

**Solutions:**
1. Increase service timeouts:
   ```bash
   curl -X PATCH $KONG_ADMIN/services/hello-service \
     -d "connect_timeout=60000" \
     -d "read_timeout=60000"
   ```
2. Check upstream response time
3. Review backend service logs

---

## References

- [Kong Admin API Documentation](https://docs.konghq.com/gateway/latest/admin-api/)
- [Kong Service Object](https://docs.konghq.com/gateway/latest/admin-api/services/)
- [Kong Route Object](https://docs.konghq.com/gateway/latest/admin-api/routes/)
- [Kong Upstream Object](https://docs.konghq.com/gateway/latest/admin-api/upstreams/)
- [Kong Plugins](https://docs.konghq.com/hub/)

---

## Next Steps

1. ✅ Set up basic routing (this guide)
2. 📖 Add authentication → See Kong authentication plugins
3. 📖 Configure rate limiting → See `rate-limiting` plugin
4. 📖 Set up monitoring → See Kong Vitals (Enterprise) or Prometheus plugin
5. 📖 Enable caching → See `proxy-cache` plugin

