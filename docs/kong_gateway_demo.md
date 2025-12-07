# Kong Gateway OSS Demo Guide

## Overview

This guide explains how to use the self-hosted Kong Gateway OSS setup with centralized management for API routing and load balancing.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Internet                                │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                    ┌───────▼────────┐
                    │   API Gateway  │
                    └───────┬────────┘
                            │
                    ┌───────▼────────┐
                    │      ALB       │
                    └───────┬────────┘
                            │
                    ┌───────▼────────┐
                    │  Kong NLB      │
                    └───────┬────────┘
                            │
         ┌──────────────────┼──────────────────┐
         │                  │                  │
    ┌────▼─────┐      ┌────▼─────┐      ┌────▼─────┐
    │  Kong DP │      │  Kong DP │      │  Kong DP │
    │ (Fargate)│      │ (Fargate)│      │ (Fargate)│
    └────┬─────┘      └────┬─────┘      └────┬─────┘
         │                  │                  │
         └──────────────────┼──────────────────┘
                            │
                    ┌───────▼────────┐
                    │ Hello Service  │
                    │   (Fargate)    │
                    └────────────────┘

Management Plane (Internal):
┌─────────────────┐    ┌──────────────────┐
│   Kong Control  │    │   PostgreSQL     │
│   Plane (CP)    │◄───┤   Database       │
│   (Fargate)     │    │   (Fargate)      │
└────────┬────────┘    └──────────────────┘
         │
         │ Admin API (Port 8001)
         ▼
┌─────────────────┐
│  Admin NLB      │
│  (Internal)     │
└─────────────────┘
```

## Components

### 1. Kong Control Plane (CP)
- **Image**: `kong:3.8-alpine` (OSS version)
- **Role**: Control plane with PostgreSQL database
- **Ports**:
  - 8001: Admin API (for management)
  - 8005: Cluster communication (to data planes)
  - 8006: Telemetry endpoint
- **Database**: PostgreSQL 13
- **Service Discovery**: `kong-cp.sbxservice.dev.local`

### 2. Kong Data Plane (DP)
- **Image**: `kong:3.8-alpine` (OSS version)
- **Role**: Data plane (handles traffic)
- **Ports**:
  - 8000: Proxy port (HTTP traffic)
  - 8443: Proxy port (HTTPS traffic)
  - 8100: Status API (health checks)
- **Mode**: DB-less (receives config from control plane)
- **Service Discovery**: `kong-gateway.sbxservice.dev.local`

### 3. PostgreSQL Database

**Option A: RDS PostgreSQL (Recommended for Production)**
- **Service**: AWS RDS PostgreSQL 13
- **Purpose**: Stores Kong configuration
- **Port**: 5432
- **Features**: Automatic backups, Multi-AZ, Performance Insights
- **See**: [Kong RDS Guide](kong_rds_guide.md)

**Option B: ECS PostgreSQL Container (For Dev/Test)**
- **Image**: `postgres:13-alpine`
- **Purpose**: Stores Kong configuration
- **Port**: 5432
- **Service Discovery**: `postgres.sbxservice.dev.local`

### 4. Hello Service
- **Type**: Spring Boot application
- **Port**: 8080
- **Endpoints**:
  - `/hello`: Main endpoint
  - `/actuator/health`: Health check
- **Service Discovery**: `sbxservice.sbxservice.dev.local`

## Deployment

### Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform installed
3. Docker installed (for local testing)

### Step 1: Configure Terraform Variables

Create or update `terraform/terraform.tfvars`:

```hcl
# AWS Configuration
aws_region     = "us-east-1"
aws_profile    = "your-profile"
aws_account_id = "your-account-id"

# Environment
environment  = "dev"
project_name = "sbxservice"

# Kong Configuration
kong_enabled               = true
kong_control_plane_enabled = true
kong_db_enabled            = true

# Kong Database
kong_db_use_rds  = true  # Use RDS (recommended) or ECS container (false)
kong_db_name     = "kong"
kong_db_user     = "kong"
kong_db_password = "your-secure-password"  # Change this!

# RDS-specific (only if kong_db_use_rds = true)
kong_db_instance_class = "db.t3.small"  # or db.t3.micro for dev
kong_db_multi_az       = true           # false for dev/test

# Container Images
container_image_hello = "your-ecr-url/hello-service:latest"
```

### Step 2: Deploy Infrastructure

```bash
cd terraform

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

### Step 3: Wait for Services to Start

The deployment will create:
- PostgreSQL database (takes ~2 minutes)
- Kong Control Plane (takes ~3-4 minutes for migrations)
- Kong Data Planes (takes ~2 minutes)
- Hello Service

Check service status:

```bash
# List ECS services
aws ecs list-services --cluster sbxservice-dev-cluster

# Check service health
aws ecs describe-services \
  --cluster sbxservice-dev-cluster \
  --services sbxservice-dev-kong-cp-service
```

### Step 4: Get Kong Admin API Endpoint

```bash
# Get the Kong Admin API endpoint from Terraform outputs
terraform output kong_admin_api_endpoint

# Example output: http://sbxservice-dev-kong-admin-nlb-xxx.elb.us-east-1.amazonaws.com:8001
```

## Configuration

### Using the Kong Setup Script

The repository includes a helper script for Kong configuration:

```bash
# Set the Kong Admin API URL
export KONG_ADMIN_URL=$(cd terraform && terraform output -raw kong_admin_api_endpoint)

# Check Kong health
./scripts/kong-setup.sh health

# Setup hello-service with default URL
./scripts/kong-setup.sh setup

# Setup hello-service with custom URL
./scripts/kong-setup.sh setup http://sbxservice.sbxservice.dev.local:8080

# List all services
./scripts/kong-setup.sh list-services

# List all routes
./scripts/kong-setup.sh list-routes
```

### Manual Configuration via Admin API

#### 1. Create a Service

```bash
curl -X POST $KONG_ADMIN_URL/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "hello-service",
    "url": "http://sbxservice.sbxservice.dev.local:8080"
  }'
```

#### 2. Create Routes

```bash
# Route for /hello endpoint
curl -X POST $KONG_ADMIN_URL/services/hello-service/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "hello-route",
    "paths": ["/hello"],
    "strip_path": false
  }'

# Route for health check
curl -X POST $KONG_ADMIN_URL/services/hello-service/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "health-route",
    "paths": ["/actuator/health"],
    "strip_path": false
  }'
```

#### 3. Verify Configuration

```bash
# List all services
curl $KONG_ADMIN_URL/services | jq

# List all routes
curl $KONG_ADMIN_URL/routes | jq

# Check data plane status
curl $KONG_ADMIN_URL/clustering/data-planes | jq
```

## Testing

### Test Through Kong Gateway

```bash
# Get the ALB endpoint
ALB_URL=$(cd terraform && terraform output -raw alb_custom_domain_url)

# Test hello endpoint through Kong
curl $ALB_URL/hello

# Test health endpoint through Kong
curl $ALB_URL/actuator/health
```

### Test Direct Access (if direct routing is enabled)

```bash
# Enable direct routing in terraform.tfvars
direct_routing_enabled = true
direct_traffic_weight  = 50  # 50% direct, 50% through Kong

# Apply changes
terraform apply

# Test - traffic will be split between Kong and direct access
curl $ALB_URL/hello
```

## Monitoring

### CloudWatch Logs

```bash
# Kong Control Plane logs
aws logs tail /ecs/sbxservice-dev-kong-cp --follow

# Kong Data Plane logs
aws logs tail /ecs/sbxservice-dev-kong --follow

# PostgreSQL logs
aws logs tail /ecs/sbxservice-dev-postgres --follow

# Hello Service logs
aws logs tail /ecs/sbxservice-dev --follow
```

### ECS Service Status

```bash
# Check Kong Control Plane
aws ecs describe-services \
  --cluster sbxservice-dev-cluster \
  --services sbxservice-dev-kong-cp-service

# Check Kong Data Planes
aws ecs describe-services \
  --cluster sbxservice-dev-cluster \
  --services sbxservice-dev-kong-service

# Check PostgreSQL
aws ecs describe-services \
  --cluster sbxservice-dev-cluster \
  --services sbxservice-dev-postgres-service
```

### Kong Admin API Monitoring

```bash
# Check Kong status
curl $KONG_ADMIN_URL/status

# Check data plane connections
curl $KONG_ADMIN_URL/clustering/data-planes

# View all services
curl $KONG_ADMIN_URL/services

# View all routes
curl $KONG_ADMIN_URL/routes
```

## Advanced Features

### Adding Plugins

Kong supports various plugins for authentication, rate limiting, logging, etc.

#### Example: Rate Limiting

```bash
curl -X POST $KONG_ADMIN_URL/services/hello-service/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "rate-limiting",
    "config": {
      "minute": 100,
      "policy": "local"
    }
  }'
```

#### Example: Request Logging

```bash
curl -X POST $KONG_ADMIN_URL/services/hello-service/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "file-log",
    "config": {
      "path": "/dev/stdout"
    }
  }'
```

### Scaling Data Planes

```bash
# Update terraform.tfvars
kong_app_count = 3  # Scale to 3 data plane instances

# Apply changes
terraform apply
```

### Load Balancing Strategies

Kong automatically load balances traffic across healthy upstream targets. You can configure advanced load balancing:

```bash
# Create upstream with multiple targets
curl -X POST $KONG_ADMIN_URL/upstreams \
  -H "Content-Type: application/json" \
  -d '{
    "name": "hello-upstream",
    "algorithm": "round-robin"
  }'

# Add targets
curl -X POST $KONG_ADMIN_URL/upstreams/hello-upstream/targets \
  -H "Content-Type: application/json" \
  -d '{
    "target": "sbxservice.sbxservice.dev.local:8080",
    "weight": 100
  }'
```

## Troubleshooting

### Kong Control Plane Not Starting

1. Check PostgreSQL is running:
   ```bash
   aws ecs describe-services --cluster sbxservice-dev-cluster \
     --services sbxservice-dev-postgres-service
   ```

2. Check Kong CP logs:
   ```bash
   aws logs tail /ecs/sbxservice-dev-kong-cp --follow
   ```

3. Verify database connection:
   ```bash
   # Connect to Kong CP container
   TASK_ID=$(aws ecs list-tasks --cluster sbxservice-dev-cluster \
     --service-name sbxservice-dev-kong-cp-service \
     --query 'taskArns[0]' --output text | cut -d'/' -f3)
   
   aws ecs execute-command --cluster sbxservice-dev-cluster \
     --task $TASK_ID \
     --container sbxservice-dev-kong-cp-container \
     --interactive --command "/bin/sh"
   ```

### Data Planes Not Connecting

1. Check data plane logs:
   ```bash
   aws logs tail /ecs/sbxservice-dev-kong --follow
   ```

2. Verify control plane is reachable:
   ```bash
   # From data plane container
   ping kong-cp.sbxservice.dev.local
   ```

3. Check cluster status:
   ```bash
   curl $KONG_ADMIN_URL/clustering/data-planes
   ```

### Routes Not Working

1. Verify service and route configuration:
   ```bash
   curl $KONG_ADMIN_URL/services/hello-service
   curl $KONG_ADMIN_URL/services/hello-service/routes
   ```

2. Check if hello-service is reachable:
   ```bash
   # From Kong container
   curl http://sbxservice.sbxservice.dev.local:8080/hello
   ```

3. Test Kong proxy directly:
   ```bash
   # Get Kong NLB DNS
   KONG_NLB=$(cd terraform && terraform output -raw kong_nlb_dns_name)
   curl http://$KONG_NLB:8000/hello
   ```

## Cost Optimization

### Current Setup Costs (Approximate)

- **ECS Fargate**:
  - Kong Control Plane: 1 task (1 vCPU, 2GB) = ~$35/month
  - Kong Data Planes: 1 task (1 vCPU, 2GB) = ~$35/month
  - PostgreSQL: 1 task (0.5 vCPU, 1GB) = ~$18/month
  - Hello Service: 1 task (1 vCPU, 2GB) = ~$35/month
- **Load Balancers**:
  - ALB: ~$22/month
  - Kong NLB: ~$22/month
  - Admin NLB: ~$22/month
- **Data Transfer**: Variable based on usage

**Total**: ~$189/month (excluding data transfer)

### Cost Reduction Tips

1. **Use Spot Instances**: Not available for Fargate, consider EC2
2. **Reduce Task Count**: Run single instances for dev/test
3. **Share Database**: Use RDS with reserved instances for production
4. **Remove Unused NLBs**: Combine Admin API access with main NLB

## Cleanup

To destroy all resources:

```bash
cd terraform
terraform destroy
```

This will remove:
- All ECS services and tasks
- Load balancers
- Security groups
- CloudWatch log groups
- Secrets Manager secrets

## Next Steps

1. **Add Authentication**: Implement JWT or OAuth plugins
2. **Enable HTTPS**: Configure SSL/TLS certificates
3. **Add Monitoring**: Integrate with Prometheus/Grafana
4. **Implement CI/CD**: Automate Kong configuration updates
5. **Multi-Region**: Deploy Kong in multiple AWS regions
6. **Custom Plugins**: Develop Kong plugins for specific needs

## References

- [Kong Gateway Documentation](https://docs.konghq.com/gateway/latest/)
- [Kong Admin API Reference](https://docs.konghq.com/gateway/latest/admin-api/)
- [Kong Plugin Hub](https://docs.konghq.com/hub/)
- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)

