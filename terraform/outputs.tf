# API Gateway outputs
output "api_gateway_endpoint" {
  description = "The API Gateway endpoint URL"
  value       = module.api_gateway.api_endpoint
}

# ALB and endpoint outputs
output "alb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = module.ecs.alb_dns_name
}

output "http_endpoint" {
  description = "The HTTP endpoint of the load balancer"
  value       = module.ecs.http_endpoint
}

output "https_endpoint" {
  description = "The HTTPS endpoint of the load balancer (if enabled)"
  value       = module.ecs.https_endpoint
}

# App Mesh outputs
output "mesh_name" {
  description = "The name of the App Mesh service mesh"
  value       = module.app_mesh.mesh_name
}

# Network Firewall outputs
output "network_firewall_status" {
  description = "Network Firewall status details"
  value       = module.network_firewall.firewall_status
}

output "firewall_policy_id" {
  description = "ID of the Network Firewall Policy"
  value       = module.network_firewall.firewall_policy_id
}

output "network_firewall_flow_logs" {
  description = "CloudWatch Log Group for Network Firewall flow logs"
  value       = module.network_firewall.flow_log_group
}

output "network_firewall_alert_logs" {
  description = "CloudWatch Log Group for Network Firewall alert logs"
  value       = module.network_firewall.alert_log_group
}

# Container image outputs
output "container_images" {
  description = "Map of container images being used for each service"
  value       = local.container_images
} 