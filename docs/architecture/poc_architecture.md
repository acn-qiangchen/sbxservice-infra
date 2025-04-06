# SBXService POC Architecture

## Overview

This document outlines a minimal viable architecture for the SBXService POC on AWS, focusing on deploying a simple "Hello World" Spring Boot microservice on Amazon ECS with Fargate.

## Architecture Diagram

```
                   ┌───────────────┐
                   │  API Gateway  │
                   └───────┬───────┘
                           │
                           ▼
  ┌─────────────────────────────────────────┐
  │                                         │
  │  ECS Cluster (Fargate)                  │
  │  ┌─────────────────────────────────┐    │
  │  │                                 │    │
  │  │   Spring Boot Service Container │    │
  │  │   (Hello World API)             │    │
  │  │                                 │    │
  │  └─────────────────────────────────┘    │
  │                                         │
  └─────────────────────────────────────────┘
```

## Core Components

1. **Spring Boot Service**
   - Simple containerized Spring Boot application providing a "Hello World" REST API
   - Deployed to ECS Fargate (serverless containers)
   - Accessible via API Gateway
   - Default Fargate configuration (0.25 vCPU, 0.5GB memory) should be sufficient

2. **Networking & Security**
   - VPC with public subnets for ECS tasks
   - Security groups for network traffic control
   - IAM roles for service permissions

3. **Monitoring**
   - Basic CloudWatch metrics for service monitoring
   - Container logs sent to CloudWatch Logs

## CI/CD Pipeline (Minimal)

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
   - Configure task definition and service
   - Set up API Gateway with HTTP API type for simplicity

3. **CI/CD Pipeline**
   - Configure GitHub Actions workflow for:
     - Building the Spring Boot application
     - Creating and pushing Docker image to ECR
     - Deploying updated task definition to ECS

## Infrastructure Considerations

1. **Cost Optimization**
   - Standard Fargate pricing will apply
   - No auto-scaling required for POC
   - API Gateway will use pay-per-use pricing model

2. **Security**
   - Basic security groups to allow inbound traffic only to required ports
   - IAM roles with least privilege for ECS tasks
   - No custom domain or SSL/TLS requirements for the POC phase

## Next Steps After POC

1. **Evaluation Criteria**
   - Successful deployment of Spring Boot application to ECS Fargate
   - Accessible API endpoints via API Gateway
   - Functional CI/CD pipeline

2. **Potential Enhancements for Production**
   - Custom domain name with SSL/TLS
   - Enhanced monitoring and alerting
   - Authentication and authorization
   - Data persistence layer
   - Auto-scaling based on traffic patterns

This minimal architecture provides a solid foundation for demonstrating the core functionality while keeping complexity and costs to a minimum. It can be expanded upon based on the POC results and feedback. 