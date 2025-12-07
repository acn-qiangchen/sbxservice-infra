# Kong Gateway with RDS PostgreSQL

## Overview

This guide explains how to use RDS PostgreSQL instead of an ECS container for Kong's database. RDS is recommended for production deployments.

## Why Use RDS?

### Advantages

✅ **Managed Service**
- Automatic backups with point-in-time recovery
- Automated patching and updates
- Built-in monitoring and metrics

✅ **High Availability**
- Multi-AZ deployment option
- Automatic failover
- Read replicas for scaling

✅ **Performance**
- Optimized storage (gp3, io1, io2)
- Better IOPS and throughput
- Performance Insights

✅ **Security**
- Encryption at rest and in transit
- Automated backups
- Network isolation

✅ **Scalability**
- Easy vertical scaling (instance class)
- Storage autoscaling
- Read replicas

### When to Use Each Option

| Feature | RDS PostgreSQL | ECS PostgreSQL |
|---------|---------------|----------------|
| **Best for** | Production | Dev/Test/Demo |
| **Cost** | Higher (~$15-200/month) | Lower (~$18/month) |
| **Management** | AWS Managed | Self-managed |
| **Backups** | Automatic | Manual |
| **HA** | Multi-AZ | Single instance |
| **Performance** | Optimized | Basic |
| **Scaling** | Easy | Manual |

## Configuration

### Using RDS (Recommended for Production)

```hcl
# terraform.tfvars

# Enable RDS
kong_db_use_rds = true

# Database configuration
kong_db_name     = "kong"
kong_db_user     = "kong"
kong_db_password = "your-secure-password"

# RDS instance configuration
kong_db_instance_class      = "db.t3.small"  # or db.t3.medium for production
kong_db_allocated_storage   = 20
kong_db_multi_az            = true           # Enable for production HA
kong_db_deletion_protection = true           # Enable for production
kong_db_skip_final_snapshot = false          # Keep final snapshot
```

### Using ECS Container (For Dev/Test)

```hcl
# terraform.tfvars

# Use ECS container instead of RDS
kong_db_use_rds = false

# Database configuration
kong_db_name     = "kong"
kong_db_user     = "kong"
kong_db_password = "your-secure-password"
```

## Deployment

### Deploy with RDS

```bash
cd terraform

# Initialize
terraform init

# Plan
terraform plan

# Apply
terraform apply

# Get RDS endpoint
terraform output kong_db_endpoint
```

### Migration from ECS to RDS

If you're currently using ECS PostgreSQL and want to migrate to RDS:

#### Step 1: Backup Current Data

```bash
# Get PostgreSQL task ID
TASK_ID=$(aws ecs list-tasks \
  --cluster sbxservice-dev-cluster \
  --service-name sbxservice-dev-postgres-service \
  --query 'taskArns[0]' --output text | cut -d'/' -f3)

# Connect to PostgreSQL container
aws ecs execute-command \
  --cluster sbxservice-dev-cluster \
  --task $TASK_ID \
  --container sbxservice-dev-postgres-container \
  --interactive --command "/bin/sh"

# Inside container, backup database
pg_dump -U kong -d kong > /tmp/kong_backup.sql
exit

# Copy backup from container (if needed)
# Note: You may need to use S3 or another method to extract the backup
```

#### Step 2: Update Configuration

```hcl
# terraform.tfvars

# Switch to RDS
kong_db_use_rds = true

# Configure RDS
kong_db_instance_class = "db.t3.small"
kong_db_multi_az       = true
```

#### Step 3: Apply Changes

```bash
terraform apply
```

This will:
1. Create RDS PostgreSQL instance
2. Update Kong Control Plane to use RDS
3. Keep ECS PostgreSQL running (for rollback)

#### Step 4: Restore Data to RDS

```bash
# Get RDS endpoint
RDS_ENDPOINT=$(terraform output -raw kong_db_endpoint | cut -d':' -f1)

# Restore backup to RDS
psql -h $RDS_ENDPOINT -U kong -d kong < kong_backup.sql
```

#### Step 5: Verify and Clean Up

```bash
# Verify Kong Control Plane is working
export KONG_ADMIN_URL=$(terraform output -raw kong_admin_api_endpoint)
curl $KONG_ADMIN_URL/status

# If everything works, you can remove ECS PostgreSQL by setting:
# kong_db_enabled = false (if you don't need the ECS container anymore)
```

## RDS Configuration Options

### Instance Classes

| Class | vCPU | Memory | Use Case | Cost/Month* |
|-------|------|--------|----------|-------------|
| db.t3.micro | 2 | 1 GB | Dev/Test | ~$15 |
| db.t3.small | 2 | 2 GB | Small Production | ~$30 |
| db.t3.medium | 2 | 4 GB | Medium Production | ~$60 |
| db.t3.large | 2 | 8 GB | Large Production | ~$120 |
| db.r6g.large | 2 | 16 GB | High Memory | ~$150 |

*Approximate costs for us-east-1

### Storage Options

```hcl
# General Purpose SSD (gp3) - Recommended
db_allocated_storage     = 20   # Initial size in GB
db_max_allocated_storage = 100  # Auto-scaling limit

# For high IOPS workloads, consider io1/io2 via RDS console
```

### High Availability

```hcl
# Enable Multi-AZ for automatic failover
kong_db_multi_az = true

# Backup configuration
backup_retention_period = 7  # Days (default in module)

# Maintenance window
# Configured in module: mon:04:00-mon:05:00 UTC
```

## Monitoring

### CloudWatch Metrics

The RDS module automatically creates CloudWatch alarms for:

- **CPU Utilization** > 80%
- **Freeable Memory** < 256 MB
- **Free Storage Space** < 5 GB
- **Database Connections** > 80

### View Metrics

```bash
# CPU Utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=sbxservice-dev-kong-db \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# Database Connections
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBInstanceIdentifier,Value=sbxservice-dev-kong-db \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

### Performance Insights

Performance Insights is enabled by default (7-day retention):

```bash
# View in AWS Console
# RDS → Your Database → Performance Insights
```

### Logs

PostgreSQL logs are automatically exported to CloudWatch:

```bash
# View PostgreSQL logs
aws logs tail /aws/rds/instance/sbxservice-dev-kong-db/postgresql --follow
```

## Backup and Recovery

### Automated Backups

- **Retention**: 7 days (configurable)
- **Backup Window**: 03:00-04:00 UTC
- **Point-in-Time Recovery**: Enabled

### Manual Snapshots

```bash
# Create manual snapshot
aws rds create-db-snapshot \
  --db-instance-identifier sbxservice-dev-kong-db \
  --db-snapshot-identifier kong-db-manual-snapshot-$(date +%Y%m%d)

# List snapshots
aws rds describe-db-snapshots \
  --db-instance-identifier sbxservice-dev-kong-db

# Restore from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier sbxservice-dev-kong-db-restored \
  --db-snapshot-identifier kong-db-manual-snapshot-20240101
```

### Export to S3

```bash
# Export snapshot to S3 (for long-term storage)
aws rds start-export-task \
  --export-task-identifier kong-db-export-$(date +%Y%m%d) \
  --source-arn arn:aws:rds:us-east-1:ACCOUNT_ID:snapshot:kong-db-snapshot \
  --s3-bucket-name my-db-exports \
  --iam-role-arn arn:aws:iam::ACCOUNT_ID:role/rds-s3-export-role \
  --kms-key-id arn:aws:kms:us-east-1:ACCOUNT_ID:key/KEY_ID
```

## Security

### Network Security

- RDS instance is in private subnets
- Security group allows access only from application security group
- No public access

### Encryption

- **At Rest**: Enabled by default (AWS managed keys)
- **In Transit**: SSL/TLS connections
- **Performance Insights**: Encrypted with KMS

### Connection Security

```bash
# Kong connects to RDS using:
# - Private network (no internet)
# - SSL/TLS encryption
# - Database credentials from Secrets Manager
```

## Cost Optimization

### Development/Testing

```hcl
kong_db_instance_class = "db.t3.micro"
kong_db_multi_az       = false
backup_retention_period = 1
```

**Estimated Cost**: ~$15/month

### Production

```hcl
kong_db_instance_class = "db.t3.small"  # or larger
kong_db_multi_az       = true
backup_retention_period = 7
```

**Estimated Cost**: ~$60/month (with Multi-AZ)

### Cost Reduction Tips

1. **Right-size instance**: Start small, scale up as needed
2. **Use Reserved Instances**: Save up to 60% with 1-year commitment
3. **Optimize storage**: Use gp3 instead of io1 when possible
4. **Clean up snapshots**: Delete old manual snapshots
5. **Use Aurora Serverless**: Consider for variable workloads

## Troubleshooting

### RDS Connection Issues

```bash
# Check RDS status
aws rds describe-db-instances \
  --db-instance-identifier sbxservice-dev-kong-db \
  --query 'DBInstances[0].DBInstanceStatus'

# Check security group
aws rds describe-db-instances \
  --db-instance-identifier sbxservice-dev-kong-db \
  --query 'DBInstances[0].VpcSecurityGroups'

# Test connection from Kong CP
TASK_ID=$(aws ecs list-tasks \
  --cluster sbxservice-dev-cluster \
  --service-name sbxservice-dev-kong-cp-service \
  --query 'taskArns[0]' --output text | cut -d'/' -f3)

aws ecs execute-command \
  --cluster sbxservice-dev-cluster \
  --task $TASK_ID \
  --container sbxservice-dev-kong-cp-container \
  --interactive --command "/bin/sh"

# Inside container
apk add postgresql-client
psql -h $KONG_PG_HOST -U kong -d kong -c "SELECT version();"
```

### Performance Issues

```bash
# Check CloudWatch alarms
aws cloudwatch describe-alarms \
  --alarm-name-prefix sbxservice-dev-kong-db

# Check slow queries
aws rds download-db-log-file-portion \
  --db-instance-identifier sbxservice-dev-kong-db \
  --log-file-name error/postgresql.log
```

## Best Practices

### Production Checklist

- [ ] Use db.t3.small or larger instance class
- [ ] Enable Multi-AZ deployment
- [ ] Set backup retention to 7+ days
- [ ] Enable deletion protection
- [ ] Disable skip_final_snapshot
- [ ] Set up CloudWatch alarms
- [ ] Configure SNS notifications
- [ ] Enable Performance Insights
- [ ] Use strong database password
- [ ] Store password in Secrets Manager
- [ ] Enable automated backups
- [ ] Test restore procedure
- [ ] Document connection strings
- [ ] Set up monitoring dashboard

### Maintenance

- **Regular Tasks**:
  - Review CloudWatch alarms weekly
  - Check Performance Insights monthly
  - Test backup restore quarterly
  - Review and optimize queries
  - Update instance class as needed

- **Patching**:
  - Automatic minor version upgrades enabled
  - Major version upgrades: test in staging first
  - Maintenance window: Monday 04:00-05:00 UTC

## Comparison: RDS vs ECS PostgreSQL

### Performance

| Metric | RDS | ECS Container |
|--------|-----|---------------|
| IOPS | 3000-16000 | Limited by EBS |
| Storage | gp3/io1 optimized | gp2 |
| Memory | Dedicated | Shared with container |
| CPU | Dedicated | Shared |
| Latency | Lower | Higher |

### Reliability

| Feature | RDS | ECS Container |
|---------|-----|---------------|
| Backups | Automatic | Manual |
| HA | Multi-AZ | Single instance |
| Failover | Automatic | Manual |
| Monitoring | Built-in | Custom |
| Patching | Automatic | Manual |

### Cost (Monthly)

| Configuration | RDS | ECS |
|---------------|-----|-----|
| Dev/Test | $15-30 | $18 |
| Production | $60-150 | $35 |
| HA Production | $120-300 | N/A |

## Conclusion

**Use RDS when:**
- Running production workloads
- Need high availability
- Want automated backups and patching
- Require better performance
- Have budget for managed services

**Use ECS Container when:**
- Running dev/test environments
- Cost is primary concern
- Don't need HA
- Comfortable with self-management
- Temporary/demo deployments

For this Kong Gateway setup, **RDS is recommended for production** due to its reliability, performance, and managed features.

