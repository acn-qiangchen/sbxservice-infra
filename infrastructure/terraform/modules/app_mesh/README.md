# AWS App Mesh Module

This Terraform module creates an AWS App Mesh service mesh and necessary components for a Spring Boot application running on ECS Fargate.

## Components

1. **App Mesh Service Mesh**
   - The core mesh that manages service-to-service communication

2. **Virtual Node**
   - Represents the Spring Boot service in the mesh
   - Configured with health checks and service discovery

3. **Virtual Router and Route**
   - Routes traffic to the virtual node
   - Can be extended for more complex routing patterns

4. **Virtual Service**
   - The entry point for service communication
   - Used by other services to discover and communicate with the service

5. **Service Discovery**
   - AWS Cloud Map namespace and service for service discovery
   - Enables automatic registration of service instances

## Usage

```hcl
module "app_mesh" {
  source = "./modules/app_mesh"
  
  project_name   = "sbxservice"
  environment    = "dev"
  vpc_id         = module.vpc.vpc_id
  container_port = 8080
}
```

## Integration with ECS

To integrate with ECS, you need to:

1. Use the App Mesh Envoy container as a sidecar
2. Configure the task definition with App Mesh proxy configuration
3. Add proper IAM permissions for App Mesh and service discovery
4. Configure service discovery for the ECS service

See the ECS module for the complete implementation.

## Observability

The App Mesh setup includes:

1. **X-Ray Tracing**
   - For distributed tracing across the service mesh
   - Requires the X-Ray daemon container as a sidecar

2. **CloudWatch Logs**
   - For Envoy proxy logs
   - Configured with separate log groups for the application and Envoy

## Benefits

1. **Traffic Management**
   - Control service-to-service communication
   - Implement advanced routing policies
   - Support for canary deployments and blue/green deployments

2. **Resilience**
   - Circuit breaking
   - Retry policies
   - Timeout configuration

3. **Observability**
   - End-to-end visibility into service traffic
   - Metrics, logs, and traces in one place
   - Troubleshoot service issues more easily 