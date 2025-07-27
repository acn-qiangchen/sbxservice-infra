output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "alb_arn" {
  description = "ARN of the load balancer"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the load balancer"
  value       = aws_lb.main.zone_id
}

output "lb_listener_arn" {
  description = "ARN of the load balancer listener"
  value       = aws_lb_listener.http.arn
}

output "task_execution_role_arn" {
  description = "ARN of the task execution role"
  value       = aws_iam_role.ecs_execution_role.arn
}

output "task_role_arn" {
  description = "ARN of the task role"
  value       = aws_iam_role.ecs_task_role.arn
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.app.name
}

# Kong Gateway outputs
output "kong_nlb_arn" {
  description = "ARN of the Kong Gateway Network Load Balancer"
  value       = var.kong_enabled ? aws_lb.kong_nlb[0].arn : null
}

output "kong_nlb_dns_name" {
  description = "DNS name of the Kong Gateway Network Load Balancer"
  value       = var.kong_enabled ? aws_lb.kong_nlb[0].dns_name : null
}

output "kong_nlb_zone_id" {
  description = "Zone ID of the Kong Gateway Network Load Balancer"
  value       = var.kong_enabled ? aws_lb.kong_nlb[0].zone_id : null
}

output "kong_service_name" {
  description = "Name of the Kong Gateway ECS service"
  value       = var.kong_enabled ? aws_ecs_service.kong_gateway[0].name : null
}

output "kong_task_definition_arn" {
  description = "ARN of the Kong Gateway task definition"
  value       = var.kong_enabled ? aws_ecs_task_definition.kong_gateway[0].arn : null
}

output "kong_log_group_name" {
  description = "Name of the Kong Gateway CloudWatch log group"
  value       = var.kong_enabled ? aws_cloudwatch_log_group.kong_app[0].name : null
}

# Kong Gateway secrets outputs
output "kong_cluster_cert_secret_arn" {
  description = "ARN of the Kong Gateway cluster certificate secret"
  value       = var.kong_enabled ? aws_secretsmanager_secret.kong_cluster_cert[0].arn : null
}

output "kong_cluster_cert_key_secret_arn" {
  description = "ARN of the Kong Gateway cluster certificate key secret"
  value       = var.kong_enabled ? aws_secretsmanager_secret.kong_cluster_cert_key[0].arn : null
}

# Service Discovery outputs
output "service_discovery_namespace_id" {
  description = "ID of the service discovery namespace"
  value       = aws_service_discovery_private_dns_namespace.service_discovery.id
}

output "service_discovery_namespace_name" {
  description = "Name of the service discovery namespace"
  value       = aws_service_discovery_private_dns_namespace.service_discovery.name
}

output "hello_service_discovery_arn" {
  description = "ARN of the hello-service discovery service"
  value       = aws_service_discovery_service.hello_service.arn
}

output "kong_service_discovery_arn" {
  description = "ARN of the Kong Gateway service discovery service"
  value       = var.kong_enabled ? aws_service_discovery_service.kong_gateway[0].arn : null
} 