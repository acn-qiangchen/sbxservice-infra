variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, test, prod)"
  type        = string
}

variable "region" {
  description = "The AWS region to deploy resources"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "public_subnets" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "private_subnets" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "public_sg_id" {
  description = "ID of the public security group"
  type        = string
}

variable "application_sg_id" {
  description = "ID of the application security group"
  type        = string
}

variable "container_image_url" {
  description = "URL of the container image in ECR"
  type        = string
  default     = ""
}

variable "container_images" {
  description = "Map of container images for different services"
  type        = map(string)
  default     = {}
}

variable "task_cpu" {
  description = "CPU units for the task (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Memory for the task in MB"
  type        = number
  default     = 512
}

variable "container_port" {
  description = "Port exposed by the container"
  type        = number
  default     = 8080
}

variable "app_count" {
  description = "Number of containers to run"
  type        = number
  default     = 1
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for HTTPS"
  type        = string
  default     = ""
}

variable "enable_https" {
  description = "Whether to enable HTTPS listener (should be true when certificate is provided)"
  type        = bool
  default     = false
}



# Kong Gateway variables
variable "kong_enabled" {
  description = "Whether to enable Kong Gateway service"
  type        = bool
  default     = true
}



variable "kong_app_count" {
  description = "Number of Kong Gateway containers to run"
  type        = number
  default     = 1
}

# Gloo Gateway variables
variable "gloo_enabled" {
  description = "Whether to enable Gloo Gateway service"
  type        = bool
  default     = false
} 