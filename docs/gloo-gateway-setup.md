# Gloo Gateway Setup Guide

This guide explains how to set up Gloo Gateway alongside Kong Gateway in the sbxservice infrastructure, following the ALB-NLB-GW-BackEndService pattern with header-based routing.

## Architecture Overview

The new dual-gateway architecture provides header-based routing through a shared ALB:

```
Internet → ALB → {Header Routing} → {Kong NLB → Kong Gateway (ECS)} → Hello Service (ECS)
                                 → {Gloo NLB → Gloo Gateway (EKS)} → Hello Service (ECS)
```

### Header-Based Routing Rules

- `X-Gateway: kong` → Routes to Kong Gateway
- `X-Gateway: gloo` → Routes to Gloo Gateway  
- No header or other values → Routes directly to Hello Service

## Components

### Infrastructure Components

1. **EKS Fargate Cluster**: Minimal serverless Kubernetes cluster for Gloo Gateway control plane
2. **Gloo NLB**: Internal Network Load Balancer for Gloo Gateway traffic
3. **ALB Routing Rules**: Header-based routing to choose between gateways
4. **Shared Hello Service**: Both gateways connect to the same ECS-based backend

### Software Components

1. **Gloo Gateway Open Source**: Kubernetes-native API gateway
2. **Helm Charts**: For Gloo Gateway installation and configuration
3. **Custom Resources**: HTTPRoute, Gateway, and Upstream configurations

## Deployment Steps

### 1. Deploy Infrastructure

Enable Gloo Gateway in your Terraform configuration:

```hcl
# terraform.tfvars
gloo_enabled = true
kong_enabled = true  # Keep Kong enabled for dual-gateway setup
```

Deploy the infrastructure:

```bash
cd terraform
terraform plan
terraform apply
```

This creates:
- EKS Fargate cluster for Gloo Gateway
- Gloo NLB and target groups
- Updated ALB listener rules for header routing
- Required IAM roles and security groups

### 2. Install Gloo Gateway

Use the provided script to install Gloo Gateway:

```bash
# Set environment variables
export AWS_PROFILE=your-profile
export AWS_REGION=us-east-1
export CLUSTER_NAME=sbxservice-dev-gloo-cluster

# Run the installation script
./scripts/setup-gloo-gateway.sh
```

This script will:
- Configure kubectl for the EKS cluster
- Add Gloo Gateway Helm repository
- Install Gloo Gateway Open Source edition
- Configure the gateway proxy as an internal NLB

### 3. Configure Gloo Gateway

Apply the Gloo Gateway configuration to connect to the hello-service:

```bash
kubectl apply -f kubernetes/gloo-gateway-config.yaml
```

This configuration:
- Creates an Upstream pointing to the hello-service via Cloud Map DNS
- Sets up Gateway and HTTPRoute resources for traffic routing
- Configures health checks and retry policies

### 4. Connect to Target Group (Optional)

If you need to manually register Gloo Gateway pods with the Terraform-managed target group:

```bash
./scripts/connect-gloo-to-nlb.sh
```

> **Note**: This step is typically handled automatically by the AWS Load Balancer Controller, but the script is provided for troubleshooting.

## Testing the Setup

### 1. Test Header-Based Routing

Test Kong Gateway routing:
```bash
curl -H 'X-Gateway: kong' https://alb.your-account-id.realhandsonlabs.net/
```

Test Gloo Gateway routing:
```bash
curl -H 'X-Gateway: gloo' https://alb.your-account-id.realhandsonlabs.net/
```

Test direct hello-service access:
```bash
curl https://alb.your-account-id.realhandsonlabs.net/
```

### 2. Verify Gateway Status

Check Gloo Gateway status:
```bash
kubectl get pods -n gloo-system
kubectl get gateways -A
kubectl get httproutes -A
```

Check service endpoints:
```bash
kubectl get svc -n gloo-system
```

### 3. Check Load Balancer Integration

Verify NLB target health:
```bash
aws elbv2 describe-target-health --target-group-arn $(terraform output -raw gloo_nlb_target_group_arn)
```

## Configuration Files

### Helm Values (`kubernetes/gloo-gateway-values.yaml`)

Optimized for EKS Fargate with:
- Resource limits appropriate for Fargate
- AWS Load Balancer annotations
- Security contexts and tolerations
- High availability with multiple replicas

### Gateway Configuration (`kubernetes/gloo-gateway-config.yaml`)

Includes:
- Upstream definition for hello-service
- Gateway and HTTPRoute for Kubernetes Gateway API
- VirtualService for legacy Gloo v1 API
- Service configuration for NLB integration

## Monitoring and Troubleshooting

### Common Issues

1. **Pods stuck in Pending**: Check Fargate profile and namespace selectors
2. **LoadBalancer not provisioned**: Verify AWS Load Balancer Controller installation
3. **Health checks failing**: Check security group rules and health check paths
4. **Service discovery issues**: Verify Cloud Map DNS resolution

### Useful Commands

```bash
# Check EKS cluster status
aws eks describe-cluster --name sbxservice-dev-gloo-cluster

# View Gloo Gateway logs
kubectl logs -l gloo=gateway-proxy -n gloo-system

# Check gateway configuration
kubectl get gateway gloo-gateway -n gloo-system -o yaml

# Verify upstream health
kubectl get upstream hello-service-upstream -n gloo-system -o yaml
```

### Resource Monitoring

Monitor resource usage in Fargate:
```bash
kubectl top pods -n gloo-system
kubectl describe pod -l gloo=gateway-proxy -n gloo-system
```

## Security Considerations

### Network Security
- Gloo NLB is internal-only (not internet-facing)
- Traffic flows through ALB with Web Application Firewall
- Security groups restrict access to required ports only

### Pod Security
- Non-root containers with security contexts
- Resource limits to prevent resource exhaustion
- Network policies for inter-pod communication (optional)

### Access Control
- RBAC for Kubernetes resources
- IAM roles for AWS service integration
- Service-to-service authentication via Cloud Map

## Scaling and Performance

### Horizontal Scaling
- Increase Gloo Gateway proxy replicas for higher throughput
- EKS Fargate automatically handles pod placement
- NLB supports multiple targets across AZs

### Resource Optimization
- Adjust CPU/memory requests and limits based on traffic
- Use HPA (Horizontal Pod Autoscaler) for automatic scaling
- Monitor CloudWatch metrics for optimization opportunities

## Cleanup

To remove Gloo Gateway:

```bash
# Uninstall Gloo Gateway
helm uninstall gloo-gateway -n gloo-system

# Delete namespace
kubectl delete namespace gloo-system

# Disable in Terraform
# Set gloo_enabled = false in terraform.tfvars
terraform apply
```

## Next Steps

1. **Custom Policies**: Configure rate limiting, authentication, and other policies
2. **SSL/TLS**: Set up end-to-end encryption between gateways and backends
3. **Observability**: Integrate with monitoring tools like Prometheus and Grafana
4. **GitOps**: Automate configuration updates through CI/CD pipelines

## References

- [Gloo Gateway Documentation](https://docs.solo.io/gateway/main/)
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
- [EKS Fargate User Guide](https://docs.aws.amazon.com/eks/latest/userguide/fargate.html)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)