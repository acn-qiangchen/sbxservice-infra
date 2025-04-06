# SBXService POC Architecture

## Overview

This document outlines a minimal viable architecture for the SBXService POC on AWS, focusing on deploying a simple "Hello World" Spring Boot microservice on Amazon ECS with Fargate, integrated with AWS App Mesh for service mesh capabilities.

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
  ┌───────────────────────────────────────────────┐
  │                                               │
  │  ECS Cluster (Fargate)                        │
  │  ┌───────────────────────────────────────┐    │
  │  │                AWS App Mesh           │    │
  │  │  ┌─────────────────────────────────┐  │    │
  │  │  │ ┌─────────┐     ┌─────────────┐ │  │    │
  │  │  │ │ Envoy   │     │ Spring Boot │ │  │    │
  │  │  │ │ Proxy   ├────►│ Service     │ │  │    │
  │  │  │ └─────────┘     └─────────────┘ │  │    │
  │  │  │                                 │  │    │
  │  │  │ ┌─────────┐                     │  │    │
  │  │  │ │ X-Ray   │                     │  │    │
  │  │  │ │ Daemon  │                     │  │    │
  │  │  │ └─────────┘                     │  │    │
  │  │  └─────────────────────────────────┘  │    │
  │  └───────────────────────────────────────┘    │
  │                                               │
  └───────────────────────────────────────────────┘
```

## Core Components

1. **Spring Boot Service**
   - Simple containerized Spring Boot application providing a "Hello World" REST API
   - Deployed to ECS Fargate (serverless containers)
   - Accessible via API Gateway and ALB
   - Default Fargate configuration (0.25 vCPU, 0.5GB memory) should be sufficient

2. **AWS App Mesh**
   - Service mesh architecture for fine-grained control over service-to-service communication
   - Envoy proxy sidecar container for traffic management
   - Service discovery via AWS Cloud Map
   - X-Ray integration for distributed tracing

3. **Networking & Security**
   - VPC with public and private subnets
   - Security groups for network traffic control
   - IAM roles for service permissions
   - Private subnets for ECS tasks

4. **Monitoring**
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
   - Create ECR repository for container images
   - Set up ECS cluster with Fargate launch type
   - Configure App Mesh service mesh
   - Configure task definition with Envoy sidecar
   - Set up API Gateway with REST API type

3. **CI/CD Pipeline**
   - Configure GitHub Actions workflow for:
     - Building the Spring Boot application
     - Creating and pushing Docker image to ECR
     - Deploying updated task definition to ECS

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
   - X-Ray has minimal costs for POC workloads
   - API Gateway will use pay-per-use pricing model

2. **Security**
   - Basic security groups to allow inbound traffic only to required ports
   - IAM roles with least privilege for ECS tasks
   - No custom domain or SSL/TLS requirements for the POC phase

## Next Steps After POC

1. **Evaluation Criteria**
   - Successful deployment of Spring Boot application to ECS Fargate with App Mesh
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

This architecture provides a solid foundation for demonstrating the core functionality of a service mesh while keeping complexity and costs to a minimum. It can be expanded upon based on the POC results and feedback. 