# Kong Gateway Guide

Complete guide for deploying and managing Kong Gateway OSS in Hybrid Mode on AWS ECS.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Architecture Overview](#architecture-overview)
3. [Components](#components)
4. [Deployment](#deployment)
5. [Database Options](#database-options)
6. [Configuration](#configuration)
7. [Management](#management)
8. [Scaling](#scaling)
9. [Monitoring](#monitoring)
10. [References](#references)

---

## Quick Start

### 5-Minute Setup

```bash
# 1. Deploy Infrastructure
cd terraform
export TF_VAR_aws_account_id="your-account-id"
export TF_VAR_kong_db_password="KongPassword123!"
export TF_VAR_container_image_hello="your-ecr-url/hello-service:latest"

terraform init
terraform apply -auto-approve

# 2. Get Admin API Endpoint
export KONG_ADMIN=$(terraform output -raw kong_admin_api_endpoint)
export ALB_URL=$(terraform output -raw alb_custom_domain_url)

# 3. Wait for Services (3-5 minutes)
while ! curl -s -f $KONG_ADMIN/status > /dev/null; do
    echo "Waiting for Kong Control Plane..."
    sleep 10
done
echo "Kong Control Plane is ready!"

# 4. Configure Hello Service
cd ..
./scripts/kong-setup.sh setup

# 5. Test
curl $ALB_URL/sbx/api/hello
```

### Key Endpoints

| Component | Endpoint | Purpose |
|-----------|----------|---------|
| Kong Admin API | `http://<ALB>:8001` | Manage Kong configuration |
| Kong Admin GUI | `http://<ALB>:8002` | Kong Manager OSS web interface |
| Kong Proxy | `http://<ALB>` | Access services through Kong |
| Kong Status API | `http://<kong-dp>:8100` | Data Plane health and metrics |

---

## Architecture Overview

### High-Level Architecture

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
                    │                │
                    │  Port 80/443   │ Public Traffic
                    │  Port 8001     │ Admin API
                    │  Port 8002     │ Admin GUI
                    └───────┬────────┘
                            │
         ┌──────────────────┼──────────────────┐
         │                  │                  │
    ┌────▼─────┐      ┌────▼─────┐      ┌────▼─────┐
    │  Kong DP │      │  Kong DP │      │  Kong DP │
    │ (Fargate)│      │ (Fargate)│      │ (Fargate)│
    │          │      │          │      │          │
    │ Port 8000│      │ Port 8000│      │ Port 8000│ Proxy
    │ Port 8100│      │ Port 8100│      │ Port 8100│ Status
    └────┬─────┘      └────┬─────┘      └────┬─────┘
         │                  │                  │
         └──────────────────┼──────────────────┘
                            │
                    ┌───────▼────────┐
                    │ Hello Service  │
                    │   (Fargate)    │
                    │   Port 8080    │
                    └────────────────┘

Management Plane (Internal):
┌─────────────────┐         ┌──────────────────┐
│   Kong Control  │◄───────►│    PostgreSQL    │
│   Plane (CP)    │  5432   │    (RDS/ECS)     │
│   (Fargate)     │         │                  │
│                 │         └──────────────────┘
│  Port 8001      │ Admin API
│  Port 8002      │ Admin GUI
│  Port 8005      │ Cluster Communication
│  Port 8006      │ Telemetry
└────────┬────────┘
         │
         ▼
   Data Planes (sync config via mTLS)
```

### Kong Hybrid Mode

Kong runs in **Hybrid Mode** with separated Control Plane and Data Planes:

- **Control Plane (CP)**: Stores configuration in PostgreSQL, exposes Admin API/GUI
- **Data Planes (DP)**: Handle traffic, receive configuration from CP via secure mTLS

**Benefits:**
- Scalable: Data Planes scale independently
- Resilient: CP downtime doesn't affect DP traffic proxying
- Secure: Configuration sync uses mTLS certificates

---

## Components

### 1. Kong Control Plane (CP)

**Purpose**: Central configuration management

- **Image**: `kong:3.9.1` (OSS version)
- **Role**: Control plane with PostgreSQL database
- **Ports**:
  - 8001: Admin API (REST API for configuration)
  - 8002: Admin GUI (Kong Manager OSS web interface)
  - 8005: Cluster communication (CP ← DP config sync)
  - 8006: Telemetry endpoint (DP → CP metrics)
- **Database**: PostgreSQL 13 (stores services, routes, plugins, etc.)
- **Service Discovery**: `kong-cp.sbxservice.dev.local`

**Environment Variables:**
```bash
KONG_ROLE=control_plane
KONG_DATABASE=postgres
KONG_PG_HOST=<rds-endpoint>
KONG_PG_PORT=5432
KONG_PG_USER=kong
KONG_PG_DATABASE=kong
KONG_PG_PASSWORD=<secret>
KONG_ADMIN_LISTEN=0.0.0.0:8001
KONG_ADMIN_GUI_LISTEN=0.0.0.0:8002
KONG_ADMIN_GUI_URL=http://<ALB>:8002
KONG_ADMIN_GUI_API_URL=http://<ALB>:8001
KONG_CLUSTER_LISTEN=0.0.0.0:8005
KONG_CLUSTER_TELEMETRY_LISTEN=0.0.0.0:8006
KONG_CLUSTER_MTLS=shared
KONG_CLUSTER_CERT=<secret>
KONG_CLUSTER_CERT_KEY=<secret>
```

### 2. Kong Data Plane (DP)

**Purpose**: Traffic routing and proxying

- **Image**: `kong:3.9.1` (OSS version)
- **Role**: Data plane (handles traffic, no database)
- **Ports**:
  - 8000: Proxy port (HTTP traffic)
  - 8443: Proxy port (HTTPS traffic, not yet configured)
  - 8100: Status API (health checks, metrics)
- **Mode**: DB-less (receives configuration from Control Plane)
- **Service Discovery**: `kong-gateway.sbxservice.dev.local`

**Environment Variables:**
```bash
KONG_ROLE=data_plane
KONG_DATABASE=off
KONG_CLUSTER_CONTROL_PLANE=kong-cp.sbxservice.dev.local:8005
KONG_CLUSTER_TELEMETRY_ENDPOINT=kong-cp.sbxservice.dev.local:8006
KONG_CLUSTER_MTLS=shared
KONG_CLUSTER_CERT=<secret>
KONG_CLUSTER_CERT_KEY=<secret>
KONG_STATUS_LISTEN=0.0.0.0:8100
```

### 3. PostgreSQL Database

Kong Control Plane requires PostgreSQL to store configuration.

**Two Options:**

#### Option A: AWS RDS PostgreSQL (Recommended for Production)

- **Service**: AWS RDS PostgreSQL 13
- **Purpose**: Stores Kong configuration
- **Port**: 5432
- **Features**: 
  - Automatic backups (35-day retention)
  - Multi-AZ deployment (high availability)
  - Performance Insights
  - Automated patching
  - Point-in-time recovery

**Advantages:**
- Managed service (no maintenance)
- Automatic failover
- Scalable (read replicas, vertical scaling)
- Integrated monitoring

**Configuration:**
```hcl
# terraform.tfvars
kong_db_use_rds = true
kong_db_instance_class = "db.t3.micro"
kong_db_multi_az = false  # Set true for production
kong_db_deletion_protection = false  # Set true for production
kong_db_password = "KongPassword123!"  # Change for production
```

#### Option B: ECS PostgreSQL Container (For Dev/Test Only)

- **Image**: `postgres:13-alpine`
- **Purpose**: Stores Kong configuration
- **Port**: 5432
- **Service Discovery**: `postgres.sbxservice.dev.local`

**Advantages:**
- Simple setup
- Lower cost for dev/test
- Easy to destroy/recreate

**Configuration:**
```hcl
# terraform.tfvars
kong_db_use_rds = false
kong_db_enabled = true
```

**⚠️ Not recommended for production**: No backups, no high availability, no scaling.

### 4. mTLS Certificates

Kong Hybrid Mode uses mTLS (mutual TLS) for secure communication between Control Plane and Data Planes.

**Certificate Requirements:**
- **Common Name**: MUST be `kong_clustering` (exact, required by Kong)
- **Same cert/key** used by both CP and DP
- **Validity**: 10 years (generated by Terraform)
- **Storage**: AWS Secrets Manager

**Terraform generates:**
- Self-signed certificate with CN=`kong_clustering`
- Private key (RSA 2048-bit)
- Stored in Secrets Manager, injected as ECS task secrets

---

## Deployment

### Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** >= 1.0
3. **AWS CLI** configured
4. **Docker images** pushed to ECR:
   - Hello service image
5. **GitHub Repository** (for GitHub Actions CI/CD)

### Step-by-Step Deployment

#### 1. Configure Variables

Create `terraform/terraform.tfvars`:

```hcl
# AWS Configuration
aws_region     = "us-east-1"
aws_account_id = "123456789012"

# Project Configuration
project_name = "sbxservice"
environment  = "dev"

# Container Images
container_image_hello = "123456789012.dkr.ecr.us-east-1.amazonaws.com/sbxservice-hello-service:latest"

# Kong Configuration
kong_enabled = true
kong_control_plane_enabled = true
kong_app_count = 2  # Number of Data Planes

# Database Configuration (RDS)
kong_db_use_rds = true
kong_db_password = "YourSecurePassword123!"  # Change this!
kong_db_instance_class = "db.t3.micro"
kong_db_multi_az = false
kong_db_deletion_protection = false

# Or use ECS PostgreSQL (Dev only)
# kong_db_use_rds = false
# kong_db_enabled = true
```

#### 2. Deploy Infrastructure

```bash
cd terraform

# Initialize Terraform
terraform init

# Plan deployment
terraform plan -out=tfplan

# Apply changes
terraform apply tfplan
```

**Deployment time**: 8-12 minutes

#### 3. Wait for Services to Start

```bash
# Get Kong Admin API endpoint
export KONG_ADMIN=$(terraform output -raw kong_admin_api_endpoint)

# Wait for Kong Control Plane
while ! curl -s -f $KONG_ADMIN/status > /dev/null; do
    echo "Waiting for Kong Control Plane..."
    sleep 10
done
echo "✅ Kong Control Plane is ready!"

# Verify Data Planes are connected
curl -s $KONG_ADMIN/clustering/data-planes | jq '.data | length'
# Should show 2 (or your kong_app_count value)
```

#### 4. Run Database Migrations

Kong automatically runs migrations on Control Plane startup. Verify:

```bash
# Check Kong CP logs
aws logs tail /ecs/sbxservice-dev-kong-cp --since 5m | grep -i migration
```

You should see:
```
[MIGRATION] migrations up to date
```

#### 5. Configure Services

Use the setup script:

```bash
cd ..
./scripts/kong-setup.sh setup
```

Or manually via Admin API (see [Kong Admin API Reference](kong_admin_api_reference.md)).

#### 6. Test

```bash
# Get ALB URL
export ALB_URL=$(cd terraform && terraform output -raw alb_custom_domain_url)

# Test hello service through Kong
curl $ALB_URL/sbx/api/hello

# Test health endpoint
curl $ALB_URL/actuator/health

# Access Kong Manager GUI
open http://<ALB-DNS>:8002
```

---

## Database Options

### When to Use RDS vs ECS PostgreSQL

| Feature | RDS PostgreSQL | ECS PostgreSQL |
|---------|----------------|----------------|
| **Use Case** | Production | Dev/Test only |
| **High Availability** | ✅ Multi-AZ | ❌ Single container |
| **Backups** | ✅ Automatic (35 days) | ❌ None |
| **Failover** | ✅ Automatic | ❌ Manual restart |
| **Scaling** | ✅ Vertical + Read replicas | ❌ Limited |
| **Maintenance** | ✅ Automated patching | ❌ Manual |
| **Cost** | Higher (~$15-30/month) | Lower (~$5/month) |
| **Setup Complexity** | Medium | Simple |

### RDS Setup Details

**Configuration in Terraform:**

```hcl
module "rds" {
  source = "./modules/rds"
  count  = var.kong_db_use_rds ? 1 : 0

  # Basic Configuration
  project_name        = var.project_name
  environment         = var.environment
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  database_sg_id      = module.security_groups.database_sg_id

  # Database Configuration
  db_name             = var.kong_db_name
  db_username         = var.kong_db_user
  db_password         = var.kong_db_password
  db_port             = var.kong_db_port

  # Instance Configuration
  instance_class      = var.kong_db_instance_class
  allocated_storage   = 20
  engine_version      = "13"

  # High Availability
  multi_az            = var.kong_db_multi_az
  
  # Backup and Maintenance
  backup_retention_period = 35
  preferred_backup_window = "03:00-04:00"
  preferred_maintenance_window = "Mon:04:00-Mon:05:00"
  
  # Protection
  deletion_protection = var.kong_db_deletion_protection
  skip_final_snapshot = !var.kong_db_deletion_protection
}
```

**Monitoring:**
```bash
# Check RDS status
aws rds describe-db-instances \
  --db-instance-identifier sbxservice-dev-kong-db \
  --query 'DBInstances[0].{Status:DBInstanceStatus,Endpoint:Endpoint.Address}'

# View logs
aws rds describe-db-log-files \
  --db-instance-identifier sbxservice-dev-kong-db
```

**Backup and Restore:**
```bash
# Create manual snapshot
aws rds create-db-snapshot \
  --db-instance-identifier sbxservice-dev-kong-db \
  --db-snapshot-identifier kong-manual-backup-$(date +%Y%m%d)

# List snapshots
aws rds describe-db-snapshots \
  --db-instance-identifier sbxservice-dev-kong-db

# Restore from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier sbxservice-dev-kong-db-restored \
  --db-snapshot-identifier kong-manual-backup-20250101
```

---

## Configuration

### Managing Kong Configuration

Kong configuration is managed via the **Admin API** (port 8001) or **Kong Manager GUI** (port 8002).

**Three main entities:**
1. **Services**: Backend API definitions
2. **Routes**: URL patterns that map to services
3. **Plugins**: Features like auth, rate-limiting, logging

### Common Configuration Tasks

#### Add a New Service

```bash
# Create upstream for load balancing
curl -X POST $KONG_ADMIN/upstreams \
  -d "name=my-upstream"

# Add backend targets
curl -X POST $KONG_ADMIN/upstreams/my-upstream/targets \
  -d "target=backend1.example.com:8080"

# Create service
curl -X POST $KONG_ADMIN/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-service",
    "host": "my-upstream",
    "port": 80,
    "protocol": "http"
  }'

# Create route
curl -X POST $KONG_ADMIN/services/my-service/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-route",
    "paths": ["/api/v1"],
    "strip_path": true
  }'
```

#### Configure Health Checks

```bash
curl -X PATCH $KONG_ADMIN/upstreams/my-upstream \
  -H "Content-Type: application/json" \
  -d '{
    "healthchecks": {
      "active": {
        "type": "http",
        "http_path": "/health",
        "healthy": {
          "interval": 5,
          "successes": 2
        },
        "unhealthy": {
          "interval": 5,
          "http_failures": 3
        }
      }
    }
  }'
```

#### Add Plugins

```bash
# Rate limiting
curl -X POST $KONG_ADMIN/services/my-service/plugins \
  -d "name=rate-limiting" \
  -d "config.minute=100"

# CORS
curl -X POST $KONG_ADMIN/services/my-service/plugins \
  -d "name=cors" \
  -d "config.origins=*"

# Authentication
curl -X POST $KONG_ADMIN/services/my-service/plugins \
  -d "name=key-auth"
```

**For complete API reference, see [Kong Admin API Reference](kong_admin_api_reference.md)**

---

## Management

### Viewing Status

```bash
# Kong Control Plane status
curl $KONG_ADMIN/status

# Connected Data Planes
curl $KONG_ADMIN/clustering/data-planes | jq

# List all services
curl $KONG_ADMIN/services | jq

# List all routes
curl $KONG_ADMIN/routes | jq
```

### Viewing Logs

```bash
# Kong Control Plane
aws logs tail /ecs/sbxservice-dev-kong-cp --follow

# Kong Data Plane
aws logs tail /ecs/sbxservice-dev-kong --follow

# PostgreSQL (if using ECS)
aws logs tail /ecs/sbxservice-dev-postgres --follow

# RDS Logs
aws rds download-db-log-file-portion \
  --db-instance-identifier sbxservice-dev-kong-db \
  --log-file-name error/postgresql.log.2025-01-01-00
```

### Force Service Restart

```bash
# Restart Control Plane
aws ecs update-service \
  --cluster sbxservice-dev-cluster \
  --service sbxservice-dev-kong-cp-service \
  --force-new-deployment

# Restart Data Planes
aws ecs update-service \
  --cluster sbxservice-dev-cluster \
  --service sbxservice-dev-kong-service \
  --force-new-deployment
```

---

## Scaling

### Scale Data Planes

Update `terraform.tfvars`:
```hcl
kong_app_count = 5  # Scale to 5 Data Planes
```

Apply:
```bash
terraform apply -auto-approve
```

**Auto-scaling** (optional):
- Configure ECS Service Auto Scaling based on CPU/memory
- Recommended: 2-10 Data Planes depending on traffic

### Scale Backend Services

Update `terraform.tfvars`:
```hcl
hello_service_count = 3  # Scale hello-service to 3 tasks
```

### Database Scaling

**RDS:**
```bash
# Vertical scaling (change instance size)
aws rds modify-db-instance \
  --db-instance-identifier sbxservice-dev-kong-db \
  --db-instance-class db.t3.small \
  --apply-immediately

# Add read replica
aws rds create-db-instance-read-replica \
  --db-instance-identifier sbxservice-dev-kong-db-replica \
  --source-db-instance-identifier sbxservice-dev-kong-db
```

---

## Monitoring

### Key Metrics to Monitor

1. **Kong Data Plane**:
   - Request rate (requests/second)
   - Response latency (P50, P95, P99)
   - Error rate (4xx, 5xx)
   - CPU/Memory utilization

2. **Kong Control Plane**:
   - Connected Data Planes
   - Configuration sync lag
   - Admin API response time

3. **PostgreSQL**:
   - Connection count
   - CPU utilization
   - Storage space
   - Read/Write IOPS

### CloudWatch Metrics

```bash
# ECS Service metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=sbxservice-dev-kong-service \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# RDS metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBInstanceIdentifier,Value=sbxservice-dev-kong-db \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

### Setting Up Alarms

```bash
# High CPU alarm for Kong DP
aws cloudwatch put-metric-alarm \
  --alarm-name kong-dp-high-cpu \
  --alarm-description "Alert when Kong DP CPU exceeds 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2
```

---

## Cleanup

### Destroy Infrastructure

```bash
cd terraform
terraform destroy -auto-approve
```

**Note**: If using RDS with `deletion_protection = true`, you must first disable it:

```bash
aws rds modify-db-instance \
  --db-instance-identifier sbxservice-dev-kong-db \
  --no-deletion-protection \
  --apply-immediately

# Then destroy
terraform destroy -auto-approve
```

---

## References

### Official Documentation
- [Kong Gateway Documentation](https://docs.konghq.com/gateway/latest/)
- [Kong Hybrid Mode](https://docs.konghq.com/gateway/latest/production/deployment-topologies/hybrid-mode/)
- [Kong Admin API](https://docs.konghq.com/gateway/latest/admin-api/)
- [Kong Plugins Hub](https://docs.konghq.com/hub/)

### Internal Documentation
- [Kong Admin API Reference](kong_admin_api_reference.md) - Complete API command reference
- [Kong Troubleshooting Guide](kong_troubleshooting.md) - Common issues and solutions
- [Kong Testing Guide](kong_testing_guide.md) - Comprehensive testing procedures

### Architecture Documents
- [System Architecture](system_architecture.md) - Overall system design
- [POC Architecture](poc_architecture.md) - Proof of concept details

### Setup Scripts
- `scripts/kong-setup.sh` - Automated Kong configuration
- `scripts/deploy.sh` - Deployment automation

---

## Summary

Kong Gateway OSS provides:
- ✅ API Gateway functionality (routing, load balancing)
- ✅ Centralized management via Admin API/GUI
- ✅ Scalable architecture (Control Plane + Data Planes)
- ✅ High availability (Multi-AZ RDS, multiple Data Planes)
- ✅ Extensibility (plugins for auth, rate-limiting, etc.)
- ✅ Free and open source

**Next Steps:**
1. Deploy the infrastructure
2. Configure your services via Admin API
3. Add plugins for security and monitoring
4. Scale as needed
5. Refer to [Kong Troubleshooting Guide](kong_troubleshooting.md) if issues arise

