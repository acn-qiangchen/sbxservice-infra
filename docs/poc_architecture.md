# SBXService POC Architecture

## Overview

This document outlines a minimal viable architecture for the SBXService POC on AWS, focusing on deploying a simple "Hello World" Spring Boot microservice on Amazon ECS with Fargate, integrated with AWS App Mesh for service mesh capabilities and AWS Network Firewall for enhanced security.

## Architecture Diagram

```
                   ┌───────────────┐
                   │  API Gateway  │
                   └───────┬───────┘
                           │
                           ▼
                     ┌─────────────┐
                     │     ALB     │
                     └──────┬──────┘
                            │
                            ▼
                    ┌──────────────┐
                    │AWS Network   │
                    │Firewall      │
                    └──────┬───────┘
                           │
  ┌───────────────────────┼─────────────────────────┐
  │                       ▼                         │
  │  ECS Cluster (Fargate)                          │
  │  ┌───────────────────────────────────────┐      │
  │  │                AWS App Mesh           │      │
  │  │  ┌─────────────────────────────────┐  │      │
  │  │  │ ┌─────────┐     ┌─────────────┐ │  │      │
  │  │  │ │ Envoy   │     │ Spring Boot │ │  │      │
  │  │  │ │ Proxy   ├────►│ Service     │ │  │      │
  │  │  │ └─────────┘     └─────────────┘ │  │      │
  │  │  │                                 │  │      │
  │  │  │ ┌─────────┐                     │  │      │
  │  │  │ │ X-Ray   │                     │  │      │
  │  │  │ │ Daemon  │                     │  │      │
  │  │  │ └─────────┘                     │  │      │
  │  │  └─────────────────────────────────┘  │      │
  │  └───────────────────────────────────────┘      │
  │                                                 │
  │  ┌─────────────────────────────────────────┐    │
  │  │             VPC Endpoints               │    │
  │  │  ┌─────────┐ ┌─────────┐ ┌─────────┐    │    │
  │  │  │ ECR API │ │ ECR DKR │ │   S3    │    │    │
  │  │  └─────────┘ └─────────┘ └─────────┘    │    │
  │  │                                         │    │
  │  │  ┌─────────────────┐                    │    │
  │  │  │ CloudWatch Logs │                    │    │
  │  │  └─────────────────┘                    │    │
  │  └─────────────────────────────────────────┘    │
  │                                                 │
  └─────────────────────────────────────────────────┘
```

## Core Components

1. **Spring Boot Service**
   - Simple containerized Spring Boot application providing a "Hello World" REST API
   - Deployed to ECS Fargate (serverless containers)
   - Accessible via API Gateway and ALB
   - Default Fargate configuration (1 vCPU, 2GB memory)

2. **AWS App Mesh**
   - Service mesh architecture for fine-grained control over service-to-service communication
   - Envoy proxy sidecar container for traffic management
   - Service discovery via AWS Cloud Map
   - X-Ray integration for distributed tracing

3. **AWS Network Firewall**
   - Network-level protection between public and private resources
   - Stateful inspection of traffic with Suricata-compatible rules
   - Custom Suricata rules for HTTP protocol enforcement and attack prevention
   - No TLS inspection or stateless rules
   - Dedicated firewall subnet for Network Firewall endpoints
   - Advanced security inspection for north-south traffic

4. **VPC Endpoints**
   - Private connectivity to AWS services without traversing the public internet
   - ECR API and ECR Docker Registry endpoints for container image pulls
   - S3 Gateway endpoint for ECR layer storage access
   - CloudWatch Logs endpoint for container logging
   - Enhanced security by keeping traffic within AWS network
   - Enables ECS tasks in private subnets to access AWS services through Network Firewall

5. **Networking & Security**
   - VPC with public, private, and firewall subnets
   - Security groups for network traffic control
   - IAM roles for service permissions
   - Private subnets for ECS tasks

## Network Route Table Design

The POC architecture employs a sophisticated traffic routing strategy via AWS Network Firewall to ensure all traffic between public and private subnets is inspected:

1. **Subnet Structure**
   - **Public Subnets**: Host internet-facing resources (ALB, NAT Gateway)
   - **Firewall Subnets**: Dedicated subnets for Network Firewall endpoints
   - **Private Subnets**: Host protected resources (ECS Fargate tasks)

2. **Traffic Flow Design**
   - All traffic between public and private subnets must traverse through Network Firewall endpoints
   - Each AZ has its own set of route tables to maintain traffic symmetry
   - Traffic stays within the same AZ to ensure consistent state tracking

3. **Route Table Configuration**
   - **Public Subnet Route Tables**: 
     - Local routes for intra-VPC communication
     - Internet Gateway routes for external traffic
     - Routes to private subnets point to the Network Firewall endpoint in the same AZ
   
   - **Private Subnet Route Tables**:
     - Local routes for intra-VPC communication
     - Routes to public subnets point to the Network Firewall endpoint in the same AZ
     - Internet-bound traffic routed through NAT Gateway via Network Firewall

4. **Traffic Symmetry**
   - Outbound traffic from private to public subnets traverses the firewall endpoint in the same AZ as the source
   - Return traffic from public to private subnets traverses the firewall endpoint in the same AZ as the destination
   - This design ensures both outbound and return traffic flow through the same firewall endpoint, maintaining connection state

5. **AZ Isolation**
   - Each AZ has independent traffic flows through dedicated firewall endpoints
   - Failure in one AZ doesn't impact traffic flow in other AZs
   - Ensures high availability and fault tolerance

6. **VPC Endpoints for AWS Services Access**
   - **Interface Endpoints** placed in private subnets for:
     - ECR API: Enables authentication with ECR service
     - ECR Docker Registry: Allows pulling container images
     - CloudWatch Logs: Enables logging from containers without internet access
   - **Gateway Endpoint** for S3 attached to private subnet route tables
   - Enables ECS tasks in private subnets to access AWS services without traversing the public internet
   - Maintains security boundaries by keeping AWS service traffic within AWS network
   - Reduces exposure to potential threats while ensuring critical AWS services remain accessible

```
                             ┌─────────────────────┐
                             │ Internet Gateway    │
                             └──────────┬──────────┘
                                        │
                                        ▼
      AZ-A                      AZ-A Public Subnet                  AZ-B                      AZ-B Public Subnet
┌────────────────┐           ┌────────────────────┐          ┌────────────────┐           ┌────────────────────┐
│                │           │    ┌─────────┐     │          │                │           │    ┌─────────┐     │
│                │◄──────────┤    │   ALB   │     │          │                │◄──────────┤    │   ALB   │     │
│                │           │    └────┬────┘     │          │                │           │    └────┬────┘     │
│  Firewall      │           └─────────┼──────────┘          │  Firewall      │           └─────────┼──────────┘
│  Subnet        │                     │ ▲                    │  Subnet        │                     │ ▲
│                │                     │ │                    │                │                     │ │
│  ┌──────────┐  │                     ▼ │                    │  ┌──────────┐  │                     ▼ │
│  │ Network  │  │◄────────────────────  │                    │  │ Network  │  │◄────────────────────  │
│  │ Firewall │  │                       │                    │  │ Firewall │  │                       │
│  │ Endpoint │  │                       │                    │  │ Endpoint │  │                       │
│  └────┬─────┘  │                       │                    │  └────┬─────┘  │                       │
│       │        │                       │                    │       │        │                       │
└───────┼────────┘                       │                    └───────┼────────┘                       │
        │                                │                            │                                │
        │                                │                            │                                │
        ▼                                │                            ▼                                │
┌────────────────┐                       │                    ┌────────────────┐                       │
│                │                       │                    │                │                       │
│  Private       │                       │                    │  Private       │                       │
│  Subnet        │                       │                    │  Subnet        │                       │
│                │                       │                    │                │                       │
│  ┌──────────┐  │                       │                    │  ┌──────────┐  │                       │
│  │   ECS    │  │                       └────────────────────┤  │   ECS    │  │                       └────────────────────┐
│  │  Fargate │  │                                            │  │  Fargate │  │                                            │
│  └──────────┘  │                                            │  └──────────┘  │                                            │
│                │                                            │                │                                            │
└────────────────┘                                            └────────────────┘                                            │
                                                                                                                           │
                                                                                                                           │
                                                                                                                           ▼
                                                                                                                 Traffic Flow Legend:
                                                                                                                 -------------------
                                                                                                                 → Outbound Traffic
                                                                                                                 ← Return Traffic
```

## Container Image Management

**Important Update:** ECR repository resources have been moved to a separate repository for better management. The infrastructure now expects:

1. Container images to be managed externally
2. Currently, there is one service called "hello-service" with the container image specified via the `container_image_hello` variable
3. The infrastructure is designed to be easily extended to support multiple services in the future

Example of providing the hello-service container image:

```hcl
# Direct variable assignment
container_image_hello = "123456789012.dkr.ecr.us-east-1.amazonaws.com/hello-service:latest"

# Or through the command line
terraform apply -var="container_image_hello=123456789012.dkr.ecr.us-east-1.amazonaws.com/hello-service:latest"
```

For backward compatibility, the `container_image_url` variable is still supported but deprecated.

This service-specific suffix naming approach enables:
- Clear identification of which container image is for which service
- Easy extension for additional services in the future by adding new variables with appropriate suffixes
- Support for task definitions with multiple containers when needed
- Cleaner separation of concerns between infrastructure and application code

## Monitoring

   - Basic CloudWatch metrics for service monitoring
   - Container logs sent to CloudWatch Logs
   - Distributed tracing with AWS X-Ray

## CI/CD Pipeline

```
  ┌───────────┐     ┌───────────┐     ┌────────────────┐     ┌─────────────┐
  │  GitHub   │────►│   Build   │────►│ Push to ECR    │────►│ Deploy to   │
  │  Repo     │     │   Image   │     │ Container Repo │     │ ECS Fargate │
  └───────────┘     └───────────┘     └────────────────┘     └─────────────┘
```

## Implementation Steps

1. **Spring Boot Application**
   - Create a simple Spring Boot application with a REST controller
   - Implement a basic health check endpoint
   - Containerize using Docker (create Dockerfile)

2. **AWS Infrastructure Setup**
   - Set up ECS cluster with Fargate launch type
   - Configure App Mesh service mesh
   - Deploy Network Firewall with security rules
   - Configure task definition with Envoy sidecar
   - Set up API Gateway with REST API type
   - Create VPC endpoints for ECR, S3, and CloudWatch Logs services to enable private connectivity

3. **CI/CD Pipeline**
   - Configure CI/CD workflows for:
     - Building the Spring Boot application
     - Creating and pushing Docker image to ECR
     - Deploying updated task definition to ECS

## Network Firewall Benefits

1. **Network Security**
   - Stateful inspection of traffic with managed rule groups
   - Protection against common threats and vulnerabilities
   - Deep packet inspection for malicious payloads
   - Protocol anomaly detection

2. **Security Visibility**
   - Centralized logging of network traffic
   - Alert on suspicious patterns
   - Audit trails for security events
   - Integration with AWS security services

3. **Compliance**
   - Helps meet regulatory requirements for network security
   - Provides documentation for security audits
   - Supports security best practices

## VPC Endpoints Benefits

1. **Enhanced Security**
   - Private connectivity to AWS services without traversing the public internet
   - Reduced attack surface by eliminating the need for internet gateways for AWS service traffic
   - Traffic remains within AWS network, improving security posture
   - Control access with endpoint policies and security groups

2. **Reliable Connectivity**
   - Direct, private connectivity to AWS services
   - Eliminates dependency on NAT gateways or internet gateways for AWS service traffic
   - Reduces potential points of network failure
   - Consistent performance with AWS's internal network

3. **Cost Optimization**
   - Eliminates data transfer costs through NAT gateways for AWS service traffic
   - Reduces need for bandwidth allocation to internet gateways
   - Simpler network architecture with fewer components to manage
   - Per-hour pricing for interface endpoints with minimal data processing charges

## App Mesh Benefits

1. **Traffic Management**
   - Canary deployments and blue/green deployments
   - Circuit breaking and retry policies
   - Load balancing and traffic shaping

2. **Observability**
   - End-to-end visibility of service mesh traffic
   - Metrics, logs, and traces in one place
   - Integrated with AWS X-Ray for distributed tracing

3. **Security**
   - TLS encryption for service-to-service communication
   - Identity-based policies for services
   - Integration with AWS security services

## Infrastructure Considerations

1. **Cost Optimization**
   - Standard Fargate pricing will apply
   - Additional costs for App Mesh (per hour per mesh endpoint)
   - Network Firewall costs based on number of firewall endpoints
   - X-Ray has minimal costs for POC workloads
   - API Gateway will use pay-per-use pricing model

2. **Security**
   - Basic security groups to allow inbound traffic only to required ports
   - Network Firewall for advanced traffic inspection
   - IAM roles with least privilege for ECS tasks
   - No custom domain or SSL/TLS requirements for the POC phase

## Next Steps After POC

1. **Evaluation Criteria**
   - Successful deployment of Spring Boot application to ECS Fargate with App Mesh
   - Network Firewall properly securing traffic between public and private resources
   - Accessible API endpoints via API Gateway
   - Functional CI/CD pipeline
   - Traffic management via App Mesh

2. **Potential Enhancements for Production**
   - Custom domain name with SSL/TLS
   - Enhanced monitoring and alerting
   - Authentication and authorization
   - Data persistence layer
   - Auto-scaling based on traffic patterns
   - Multi-service App Mesh implementation
   - Advanced Network Firewall rule sets

This architecture provides a solid foundation for demonstrating the core functionality of a service mesh and network security while keeping complexity and costs to a minimum. It can be expanded upon based on the POC results and feedback. 