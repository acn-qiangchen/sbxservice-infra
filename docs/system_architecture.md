# SBXService System Architecture

## Overview

This document outlines the high-level architecture of the SBXService microservice system on AWS, featuring a dual-gateway setup with Kong Gateway and Gloo Gateway for enhanced traffic management and API governance.

## Current Architecture Diagram

The system now implements a sophisticated dual-gateway architecture with header-based routing:

## Dual Gateway Architecture

### Gateway Routing Strategy

The system uses **header-based routing** through the Application Load Balancer (ALB) to determine which gateway processes the request:

- **`X-Gateway: kong`** → Routes to Kong Gateway (ECS Fargate)
- **`X-Gateway: gloo`** → Routes to Gloo Gateway (EKS Fargate)  
- **No header or other values** → Routes directly to Hello Service

### Traffic Flow

```
Internet → Route 53 → CloudFront → WAF → ALB → {Header Routing} → Gateway → Hello Service
```

### Infrastructure Components

#### Kong Gateway (ECS-based)
- **Purpose**: Enterprise-grade API gateway with Kong Connect integration
- **Platform**: ECS Fargate containers
- **Connectivity**: Kong NLB → Kong Gateway → Hello Service
- **Features**: Enterprise policies, Kong Connect management, production-ready

#### Gloo Gateway (EKS-based)  
- **Purpose**: Kubernetes-native API gateway with advanced traffic management
- **Platform**: EKS Fargate pods
- **Connectivity**: Gloo NLB → Gloo Gateway → Hello Service
- **Features**: GitOps integration, Kubernetes-native configs, cloud-native policies

#### Shared Backend Service
- **Hello Service**: Single ECS-based Spring Boot application
- **Service Discovery**: AWS Cloud Map for DNS-based service resolution
- **Connectivity**: Both gateways connect to the same backend via Cloud Map DNS

### Load Balancer Architecture

```
ALB (Internet-facing)
├── Kong Route (X-Gateway: kong) → Kong NLB (Internal) → Kong Gateway (ECS)
├── Gloo Route (X-Gateway: gloo) → Gloo NLB (Internal) → Gloo Gateway (EKS)  
└── Default Route (no header) → Hello Service (ECS)
                                     ↑
                                Both gateways → Hello Service
```

## Service Components

### Hello Service (Backend Application)
- **Purpose**: Core business logic and API endpoints
- **Platform**: ECS Fargate containers  
- **Framework**: Spring Boot with health check endpoints
- **Connectivity**: Accessible via both gateways and direct ALB routing
- **Service Discovery**: Registered in AWS Cloud Map for DNS resolution

### Kong Gateway Service
- **Purpose**: Enterprise API gateway with advanced policy management
- **Platform**: ECS Fargate containers
- **Control Plane**: Kong Connect (SaaS) for centralized management
- **Features**: Rate limiting, authentication, monitoring, enterprise policies
- **Ports**: 8000 (proxy), 8100 (admin/status)

### Gloo Gateway Service  
- **Purpose**: Kubernetes-native API gateway with GitOps integration
- **Platform**: EKS Fargate pods
- **Control Plane**: Local Kubernetes control plane
- **Features**: Gateway API compliance, advanced traffic splitting, observability
- **Port**: 8080 (proxy)

### Gateway Management
- **Shared Configuration**: Both gateways can be configured to apply similar policies
- **Independent Scaling**: Each gateway scales independently based on traffic
- **Failover Strategy**: Direct ALB routing provides fallback if gateways are unavailable

## Communication Patterns

### Gateway-Based Routing
- **Header-Based Selection**: Client specifies gateway via `X-Gateway` header
- **Default Fallback**: Direct access to hello-service when no gateway specified
- **Load Balancing**: Each gateway has its own NLB for high availability

### Service-to-Service Communication
- **Service Discovery**: AWS Cloud Map provides DNS-based service resolution
- **Network Isolation**: Private subnets with security group controls
- **Health Checks**: Automated health monitoring for all components

### Traffic Management
- **Kong Gateway**: Enterprise-grade traffic policies and rate limiting
- **Gloo Gateway**: Advanced traffic splitting and canary deployments
- **Direct Access**: Unmediated access for testing and fallback scenarios

## Infrastructure Management

### Container Orchestration
- **ECS Fargate**: Serverless containers for Kong Gateway and Hello Service
- **EKS Fargate**: Serverless Kubernetes for Gloo Gateway
- **Auto Scaling**: Automatic scaling based on CPU/memory usage and request volume

### Network Architecture
- **VPC**: Isolated network environment with public and private subnets
- **ALB**: Internet-facing load balancer with SSL termination
- **NLBs**: Internal load balancers for each gateway (Kong and Gloo)
- **Security Groups**: Fine-grained network access control

### Service Discovery Flow
1. ALB receives request and examines headers
2. ALB routes to appropriate gateway or direct to service
3. Gateways resolve backend service via Cloud Map DNS
4. Request forwarded to Hello Service instances
5. Response returned through the same path

## Deployment Strategy

### Infrastructure as Code
- AWS CDK or Terraform for resource provisioning
- Infrastructure version control alongside application code

### CI/CD Pipeline
- Source: GitHub
- Build: GitHub Actions
- Deploy: GitHub Actions
- Orchestration: GitHub Actions

## Monitoring and Observability

### Logging
- Centralized logging with CloudWatch Logs
- Structured logging format (JSON)

### Metrics
- CloudWatch Metrics for system monitoring
- Custom metrics for business KPIs

### Tracing
- X-Ray for distributed tracing
- Correlation IDs across service boundaries

### Alerting
- CloudWatch Alarms
- SNS for notifications

## Security Considerations

### Network Security
- VPC for network isolation
- Security Groups for fine-grained access control
- NACLs for subnet-level security

### Data Security
- Encryption at rest (AWS KMS)
- Encryption in transit (TLS)
- IAM policies for resource access

### API Security
- WAF for API protection
- Rate limiting
- Request validation

## Gateway Comparison

| Feature | Kong Gateway | Gloo Gateway | Direct Access |
|---------|-------------|--------------|---------------|
| **Platform** | ECS Fargate | EKS Fargate | ECS Fargate |
| **Management** | Kong Connect (SaaS) | Kubernetes-native | N/A |
| **Configuration** | Enterprise UI + API | YAML + GitOps | N/A |
| **Policies** | Enterprise features | OSS + Enterprise | Basic ALB features |
| **Use Cases** | Production workloads | Cloud-native apps | Testing/Fallback |
| **Header** | `X-Gateway: kong` | `X-Gateway: gloo` | None required |

## Future Enhancements

### Gateway Features
- **Multi-tenancy**: Separate gateway configurations per tenant
- **Policy Harmonization**: Consistent policies across both gateways
- **Advanced Observability**: Distributed tracing and metrics correlation
- **A/B Testing**: Traffic splitting between gateways for feature testing

### Infrastructure Improvements  
- **Multi-region**: Deploy gateway infrastructure across multiple AWS regions
- **Edge Computing**: CloudFront integration for global content delivery
- **Security Hardening**: WAF rules, DDoS protection, and threat detection
- **Cost Optimization**: Reserved capacity and spot instance utilization

---

*This architecture document is subject to change as the system evolves.* 