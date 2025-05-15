output "api_gateway_endpoint" {
  description = "The API Gateway endpoint URL"
  value       = module.api_gateway.api_endpoint
}

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

output "mesh_name" {
  description = "The name of the App Mesh service mesh"
  value       = module.app_mesh.mesh_name
}

output "network_firewall_status" {
  description = "Network Firewall status details"
  value       = module.network_firewall.firewall_status
}

output "container_images" {
  description = "Map of container images being used for each service"
  value       = local.container_images
} 