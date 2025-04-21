# Architecture Changes: Removing App Mesh

## Overview

This document outlines the changes made to remove AWS App Mesh from the architecture and connect the Application Load Balancer (ALB) directly to the ECS service.

## Files Modified

1. `terraform/main.tf`
   - Removed the App Mesh module call
   - Updated the ECS module parameters to disable service mesh integration
   - Removed App Mesh related outputs

2. `terraform/modules/ecs/main.tf`
   - Removed App Mesh related IAM roles and policies
   - Removed App Mesh related CloudWatch log groups
   - Simplified the container definition to remove Envoy proxy
   - Removed App Mesh proxy configuration from task definition
   - Removed service discovery integration with App Mesh

3. `terraform/modules/ecs/variables.tf`
   - Updated App Mesh related variables to indicate they are deprecated
   - Set default values for backward compatibility

4. `terraform/modules/app_mesh/README.md`
   - Updated to indicate this module is deprecated but kept for reference

5. `docs/poc_architecture.md`
   - Updated architecture diagram to remove App Mesh
   - Updated core components section to remove App Mesh references
   - Renumbered components after removal of App Mesh
   - Removed App Mesh specific content and benefits section

## Architecture Changes

### Before:
```
User → API Gateway → ALB → Network Firewall → App Mesh (Envoy Proxy + Spring Boot) → ECS
```

### After:
```
User → API Gateway → ALB → Network Firewall → Spring Boot → ECS
```

## Benefits of the Change

1. **Simplified Architecture**
   - Reduced complexity by removing an entire layer (App Mesh)
   - Fewer components to manage and maintain
   - Streamlined container deployments without sidecar proxies

2. **Resource Efficiency**
   - Eliminated Envoy proxy sidecar container resources
   - Reduced CPU and memory usage per task
   - Reduced CloudWatch logs volume

3. **Cost Savings**
   - No App Mesh service charges
   - Lower ECS resource utilization
   - Reduced log storage costs

4. **Operational Simplicity**
   - Direct routing with fewer points of failure
   - Simpler debugging and troubleshooting
   - Less complex observability requirements

## Additional Considerations

1. **Service Discovery**: The architecture no longer uses AWS Cloud Map for service discovery.

2. **Service-to-Service Communication**: If service-to-service communication is needed in the future, consider:
   - Direct service communication via ECS service discovery
   - Using ALB for service-to-service routing
   - Implementing a different service mesh solution if needed

3. **Observability**: Without App Mesh and Envoy, consider:
   - Using CloudWatch Container Insights
   - Implementing application-level tracing with X-Ray
   - Setting up custom metrics for service health monitoring

## Testing Recommendations

1. Verify that the ALB correctly routes traffic to the ECS service
2. Confirm health checks are properly configured and working
3. Validate ECS service auto-scaling based on load
4. Test API Gateway integration with the ALB
5. Verify Network Firewall rules still properly protect the service

## Deployment Strategy

For deploying this change, follow these steps:

1. Apply Terraform changes to create new infrastructure
2. Verify that the new ECS service is running correctly
3. Update DNS or API Gateway routes to point to the new service
4. Monitor for any issues during the transition
5. Once verified, remove the old resources if they exist

---
*Note: This architecture change should be deployed in a lower environment like dev or test before applying to production.* 