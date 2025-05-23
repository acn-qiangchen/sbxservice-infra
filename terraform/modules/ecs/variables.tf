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

# App Mesh variables
variable "service_mesh_enabled" {
  description = "Whether to enable App Mesh integration"
  type        = bool
  default     = false
}

variable "mesh_name" {
  description = "Name of the App Mesh service mesh"
  type        = string
  default     = ""
}

variable "virtual_node_name" {
  description = "Name of the App Mesh virtual node"
  type        = string
  default     = ""
}

variable "service_discovery_arn" {
  description = "ARN of the service discovery service"
  type        = string
  default     = ""
} 