output "api_endpoint" {
  description = "The API Gateway endpoint URL"
  value       = "https://${aws_api_gateway_rest_api.api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${var.environment}"
}

output "api_id" {
  description = "The ID of the API Gateway"
  value       = aws_api_gateway_rest_api.api.id
}

output "stage_name" {
  description = "The name of the API Gateway stage"
  value       = var.environment
}

# Add data source for the current region
data "aws_region" "current" {} 