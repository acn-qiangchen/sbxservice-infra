# Dual NLB Routing Architecture

This document explains the dual NLB routing architecture that allows traffic to flow through Kong Gateway or directly to Hello-Service.

## Architecture Overview

```
                    ┌─────────────────┐
                    │   API Gateway   │
                    └─────────┬───────┘
                              │
                    ┌─────────▼───────┐
                    │      ALB        │
                    └─────────┬───────┘
                              │
                 ┌────────────┼────────────┐
                 │            │            │
                 ▼            ▼            ▼
         ┌──────────────┐  Weighted   ┌──────────────┐
         │   NLB_1      │  Routing    │   NLB_2      │
         │ (Kong Path)  │             │ (Direct Path)│
         └──────┬───────┘             └──────┬───────┘
                │                            │
                ▼                            ▼
         ┌──────────────┐             ┌──────────────┐
         │ Kong Gateway │────────────▶│Hello-Service │
         └──────────────┘             └──────────────┘
```

## Traffic Flows

### Option 1: Through Kong Gateway (NLB_1)
- **Traffic**: `ALB → NLB_1:8000 → Kong:8000 → Hello-Service:8080`
- **Health**: `ALB health check → NLB_1:8100 → Kong:8100/status/ready`

### Option 2: Direct to Hello-Service (NLB_2)  
- **Traffic**: `ALB → NLB_2:8000 → Hello-Service:8080`
- **Health**: `ALB health check → NLB_2:8080 → Hello-Service:8080/actuator/health`

## Configuration

### Enable Direct Routing

```hcl
# In terraform.tfvars
direct_routing_enabled = true
kong_enabled          = true

# Traffic distribution (must add up to 100)
kong_traffic_weight   = 70    # 70% through Kong
direct_traffic_weight = 30    # 30% direct to Hello-Service
```

### Common Usage Scenarios

#### 1. Kong Gateway Only (Default)
```hcl
kong_enabled          = true
direct_routing_enabled = false
kong_traffic_weight   = 100
direct_traffic_weight = 0
```

#### 2. Direct Access Only
```hcl
kong_enabled          = false
direct_routing_enabled = true
kong_traffic_weight   = 0
direct_traffic_weight = 100
```

#### 3. Gradual Migration (Blue-Green)
```hcl
# Start with Kong
kong_enabled          = true
direct_routing_enabled = true
kong_traffic_weight   = 100
direct_traffic_weight = 0

# Gradually shift traffic
kong_traffic_weight   = 50
direct_traffic_weight = 50

# Complete migration to direct
kong_traffic_weight   = 0
direct_traffic_weight = 100
```

#### 4. A/B Testing
```hcl
kong_enabled          = true
direct_routing_enabled = true
kong_traffic_weight   = 80    # 80% production traffic
direct_traffic_weight = 20    # 20% test traffic
```

## Load Balancer Details

### Kong NLB (NLB_1)
- **Name**: `sbxservice-dev-kong-nlb`
- **Listeners**: 
  - Port 8000 → Kong Gateway traffic
  - Port 8100 → Kong Gateway health checks
- **Target Groups**:
  - `sbxservice-dev-kong-traffic` (port 8000)
  - `sbxservice-dev-kong-health` (port 8100)

### Direct NLB (NLB_2)
- **Name**: `sbxservice-dev-direct-nlb`  
- **Listeners**:
  - Port 8000 → Hello-Service traffic
- **Target Groups**:
  - `sbxservice-dev-direct-traffic` (port 8080)

## Monitoring and Observability

### Health Check Endpoints

| Component | Health Check URL | Expected Response |
|-----------|------------------|-------------------|
| Kong Gateway | `http://kong:8100/status/ready` | 200 OK |
| Hello-Service (via Kong) | `http://kong:8000/actuator/health` | 200 OK |
| Hello-Service (direct) | `http://hello-service:8080/actuator/health` | 200 OK |

### CloudWatch Metrics

Monitor the following metrics to understand traffic distribution:
- ALB target group health metrics
- NLB target group health metrics  
- Kong Gateway metrics (if enabled)
- ECS service metrics for both paths

## Troubleshooting

### Common Issues

1. **Health Check Failures**
   - Verify Kong Gateway status API is enabled
   - Check Hello-Service actuator endpoints
   - Ensure security groups allow health check traffic

2. **Traffic Not Routing**
   - Verify ALB target group attachments
   - Check NLB listener configurations
   - Validate ECS service registrations

3. **Weight Distribution Issues**
   - Ensure weights add up to 100%
   - Check ALB target group distribution
   - Monitor ALB access logs for traffic patterns

### Validation Commands

```bash
# Check ALB target health
aws elbv2 describe-target-health --target-group-arn <alb-target-group-arn>

# Check Kong NLB target health  
aws elbv2 describe-target-health --target-group-arn <kong-target-group-arn>

# Check Direct NLB target health
aws elbv2 describe-target-health --target-group-arn <direct-target-group-arn>

# Test endpoints directly
curl -H "Host: your-domain.com" http://<alb-dns-name>/actuator/health
```

## Security Considerations

### Network Security
- All NLBs are internal (not internet-facing)
- Traffic flows through ALB security groups
- ECS services remain in private subnets

### Kong Gateway Bypass
- Direct routing bypasses Kong's security policies
- Ensure Hello-Service has appropriate security measures
- Consider keeping Kong for authentication/authorization

## Cost Optimization

### Resource Usage
- **Kong Enabled + Direct**: 2 NLBs, additional target groups
- **Kong Only**: 1 NLB, Kong containers
- **Direct Only**: 1 NLB, no Kong overhead

### Recommendations
- Use direct routing for internal/trusted traffic
- Use Kong Gateway for external/API traffic
- Monitor cost impact of dual NLB setup
