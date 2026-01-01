# API Gateway outputs
output "api_gateway_endpoint" {
  description = "The API Gateway endpoint URL"
  value       = module.api_gateway.api_endpoint
}

# ALB outputs
output "alb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = module.ecs.alb_dns_name
}

# Container images output
output "container_images" {
  description = "Map of container images being used for each service"
  value       = local.container_images
}

# Certificate and domain outputs
output "certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = aws_acm_certificate_validation.main.certificate_arn
}

output "domain_name" {
  description = "Base domain name"
  value       = local.domain_name
}

output "alb_custom_domain" {
  description = "Custom domain name for the ALB"
  value       = local.alb_domain_name
}

output "alb_custom_domain_url" {
  description = "HTTPS URL for the ALB custom domain"
  value       = "https://${local.alb_domain_name}"
}

# Kong Gateway outputs
output "kong_nlb_dns_name" {
  description = "DNS name of the Kong Gateway Network Load Balancer"
  value       = module.ecs.kong_nlb_dns_name
}

output "kong_service_name" {
  description = "Name of the Kong Gateway ECS service"
  value       = module.ecs.kong_service_name
}

output "kong_enabled" {
  description = "Whether Kong Gateway is enabled"
  value       = var.kong_enabled
}

# Direct routing outputs
output "direct_routing_enabled" {
  description = "Whether direct routing is enabled"
  value       = var.direct_routing_enabled
}

output "direct_nlb_dns_name" {
  description = "DNS name of the Direct Network Load Balancer"
  value       = module.ecs.direct_nlb_dns_name
}

output "traffic_routing_weights" {
  description = "Current traffic routing weights"
  value = {
    kong_weight   = var.kong_traffic_weight
    direct_weight = var.direct_traffic_weight
  }
}

# Service Discovery outputs
output "service_discovery_namespace" {
  description = "Service discovery namespace name"
  value       = module.ecs.service_discovery_namespace_name
}

output "hello_service_dns_name" {
  description = "DNS name for hello-service discovery"
  value       = "${var.project_name}.${module.ecs.service_discovery_namespace_name}"
}

output "kong_service_dns_name" {
  description = "DNS name for Kong Gateway service discovery"
  value       = var.kong_enabled ? "kong-gateway.${module.ecs.service_discovery_namespace_name}" : null
}

# Kong Control Plane and Database outputs
output "postgres_dns_name" {
  description = "DNS name for PostgreSQL service discovery"
  value       = module.ecs.postgres_dns_name
}

output "kong_cp_dns_name" {
  description = "DNS name for Kong Control Plane service discovery"
  value       = module.ecs.kong_cp_dns_name
}

output "kong_admin_api_endpoint" {
  description = "Kong Admin API endpoint URL for management"
  value       = module.ecs.kong_admin_api_endpoint
}

output "kong_admin_nlb_dns_name" {
  description = "DNS name of the Kong Admin API Network Load Balancer"
  value       = module.ecs.kong_admin_nlb_dns_name
}

# RDS outputs
output "kong_db_endpoint" {
  description = "Kong RDS database endpoint"
  value       = var.kong_db_use_rds && var.kong_db_enabled ? module.rds[0].db_instance_endpoint : null
}

output "kong_db_address" {
  description = "Kong RDS database address"
  value       = var.kong_db_use_rds && var.kong_db_enabled ? module.rds[0].db_instance_address : null
}

output "kong_db_type" {
  description = "Kong database type (RDS or ECS)"
  value       = var.kong_db_use_rds ? "RDS PostgreSQL" : "ECS PostgreSQL Container"
}

