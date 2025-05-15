output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "task_definition_arn" {
  description = "ARN of the task definition"
  value       = aws_ecs_task_definition.app.arn
}

output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.app.name
}

output "alb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "http_endpoint" {
  description = "The HTTP endpoint of the load balancer"
  value       = "http://${aws_lb.main.dns_name}"
}

output "https_endpoint" {
  description = "The HTTPS endpoint of the load balancer (if enabled)"
  value       = var.enable_https && var.ssl_certificate_arn != "" ? "https://${aws_lb.main.dns_name}" : null
}

output "alb_arn" {
  description = "ARN of the load balancer"
  value       = aws_lb.main.arn
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.app.arn
}

output "lb_listener_arn" {
  description = "ARN of the load balancer listener"
  value       = var.enable_https && var.ssl_certificate_arn != "" ? aws_lb_listener.https[0].arn : aws_lb_listener.http.arn
} 