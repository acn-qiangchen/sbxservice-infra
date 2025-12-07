# Kong Gateway Quick Start Guide

## 5-Minute Setup

### 1. Deploy Infrastructure

```bash
cd terraform

# Set required variables
export TF_VAR_aws_account_id="your-account-id"
export TF_VAR_kong_db_password="your-secure-password"
export TF_VAR_container_image_hello="your-ecr-url/hello-service:latest"

# Deploy
terraform init
terraform apply -auto-approve
```

### 2. Get Admin API Endpoint

```bash
export KONG_ADMIN_URL=$(terraform output -raw kong_admin_api_endpoint)
echo "Kong Admin API: $KONG_ADMIN_URL"
```

### 3. Wait for Services (3-5 minutes)

```bash
# Check if Kong Control Plane is ready
while ! curl -s -f $KONG_ADMIN_URL/status > /dev/null; do
    echo "Waiting for Kong Control Plane..."
    sleep 10
done
echo "Kong Control Plane is ready!"
```

### 4. Configure Hello Service

```bash
cd ..
./scripts/kong-setup.sh setup
```

### 5. Test

```bash
# Get ALB URL
ALB_URL=$(cd terraform && terraform output -raw alb_custom_domain_url)

# Test through Kong
curl $ALB_URL/hello
curl $ALB_URL/actuator/health
```

## Common Commands

### Check Status

```bash
# Kong health
curl $KONG_ADMIN_URL/status

# Data planes connected
curl $KONG_ADMIN_URL/clustering/data-planes | jq

# List services
curl $KONG_ADMIN_URL/services | jq

# List routes
curl $KONG_ADMIN_URL/routes | jq
```

### Manage Services

```bash
# Create a new service
curl -X POST $KONG_ADMIN_URL/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-service",
    "url": "http://my-backend:8080"
  }'

# Create a route
curl -X POST $KONG_ADMIN_URL/services/my-service/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-route",
    "paths": ["/api/v1"]
  }'

# Delete a service
curl -X DELETE $KONG_ADMIN_URL/services/my-service
```

### Add Plugins

```bash
# Rate limiting
curl -X POST $KONG_ADMIN_URL/services/hello-service/plugins \
  -d "name=rate-limiting" \
  -d "config.minute=100"

# CORS
curl -X POST $KONG_ADMIN_URL/services/hello-service/plugins \
  -d "name=cors" \
  -d "config.origins=*"

# Request logging
curl -X POST $KONG_ADMIN_URL/services/hello-service/plugins \
  -d "name=file-log" \
  -d "config.path=/dev/stdout"
```

### View Logs

```bash
# Kong Control Plane
aws logs tail /ecs/sbxservice-dev-kong-cp --follow

# Kong Data Plane
aws logs tail /ecs/sbxservice-dev-kong --follow

# PostgreSQL
aws logs tail /ecs/sbxservice-dev-postgres --follow
```

### Scale Services

```bash
# Update terraform.tfvars
kong_app_count = 3  # Scale data planes to 3

# Apply
terraform apply -auto-approve
```

## Architecture at a Glance

```
Internet → API Gateway → ALB → Kong NLB → Kong Data Planes → Hello Service
                                              ↑
                                              |
                            Kong Control Plane ← PostgreSQL
                                   ↓
                              Admin API (8001)
```

## Key Endpoints

| Component | Endpoint | Purpose |
|-----------|----------|---------|
| Kong Admin API | `$KONG_ADMIN_URL` | Manage Kong configuration |
| Kong Proxy | `$ALB_URL` | Access services through Kong |
| Hello Service | `/hello` | Test endpoint |
| Health Check | `/actuator/health` | Service health |

## Troubleshooting

### Kong CP not starting?
```bash
# Check PostgreSQL
aws ecs describe-services --cluster sbxservice-dev-cluster \
  --services sbxservice-dev-postgres-service

# Check logs
aws logs tail /ecs/sbxservice-dev-kong-cp --follow
```

### Data planes not connecting?
```bash
# Check cluster status
curl $KONG_ADMIN_URL/clustering/data-planes

# Check logs
aws logs tail /ecs/sbxservice-dev-kong --follow
```

### Routes not working?
```bash
# Verify configuration
curl $KONG_ADMIN_URL/services/hello-service
curl $KONG_ADMIN_URL/services/hello-service/routes

# Test Kong directly
KONG_NLB=$(cd terraform && terraform output -raw kong_nlb_dns_name)
curl http://$KONG_NLB:8000/hello
```

## Cleanup

```bash
cd terraform
terraform destroy -auto-approve
```

## Next Steps

- Read the [full documentation](kong_gateway_demo.md)
- Explore [Kong plugins](https://docs.konghq.com/hub/)
- Add authentication and rate limiting
- Set up monitoring and alerts

