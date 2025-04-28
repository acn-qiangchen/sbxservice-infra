variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, test, prod)"
  type        = string
}

variable "api_gateway_url" {
  description = "URL of the API Gateway endpoint to be used in the portal"
  type        = string
} 