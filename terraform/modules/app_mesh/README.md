# App Mesh Module

> **DEPRECATED**: This module is no longer used in the current architecture. The infrastructure has been changed to connect the ALB directly to ECS services without App Mesh. This module is kept for reference purposes only.

## Overview

This module creates and configures AWS App Mesh resources for the SBXService infrastructure. It sets up a service mesh, virtual nodes, virtual routers, and routes to manage microservice communication.

## Resources Created

- App Mesh Service Mesh
- Virtual Node for service instances
- Virtual Router for traffic routing
- Route for service traffic
- Virtual Service to tie everything together
- AWS Cloud Map Private DNS Namespace for service discovery
- AWS Cloud Map Service for service registration

## Usage

```hcl
module "app_mesh" {
  source = "./modules/app_mesh"

  project_name   = var.project_name
  environment    = var.environment
  vpc_id         = module.vpc.vpc_id
  container_port = 8080
}
```

## Inputs

| Name           | Description                      | Type   | Default | Required |
|----------------|----------------------------------|--------|---------|----------|
| project_name   | Name of the project              | string | n/a     | yes      |
| environment    | Deployment environment           | string | n/a     | yes      |
| vpc_id         | ID of the VPC                    | string | n/a     | yes      |
| container_port | Port exposed by the container    | number | n/a     | yes      |

## Outputs

| Name                        | Description                                  |
|-----------------------------|----------------------------------------------|
| mesh_name                   | Name of the App Mesh service mesh            |
| virtual_node_name           | Name of the App Mesh virtual node            |
| service_discovery_namespace | DNS namespace for service discovery          |
| service_discovery_service_arn | ARN of the service discovery service       |

## Integration with ECS

This module is designed to be used with the ECS module to enable service mesh capabilities. In the ECS module, the following parameters should be provided:

```hcl
# In the main Terraform configuration
module "ecs" {
  # ... other parameters ...

  service_mesh_enabled  = true
  mesh_name             = module.app_mesh.mesh_name
  virtual_node_name     = module.app_mesh.virtual_node_name
  service_discovery_arn = module.app_mesh.service_discovery_service_arn
}
```

## Notes

- The App Mesh configuration includes Envoy Proxy sidecar containers in the ECS task definition
- X-Ray integration is enabled for distributed tracing
- Health checks are configured for both the application and Envoy containers
- Service discovery is implemented using AWS Cloud Map private DNS namespace

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