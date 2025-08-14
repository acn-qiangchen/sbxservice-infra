variable "aws_region" {
  description = "AWS region where resources will be deployed"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS profile to use"
  type        = string
  default     = ""
}

variable "aws_account_id" {
  description = "AWS account ID for domain construction and ECR"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, test, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "sbxservice"
}

# Container image variables with service-specific suffixes
variable "container_image_hello" {
  description = "URL of the container image for the hello-service"
  type        = string
  default     = ""
}

variable "container_image_kong" {
  description = "URL of the container image for the Kong Gateway service"
  type        = string
  default     = ""
}

# Map of all container images (constructed from individual image variables)
variable "container_images" {
  description = "Map of container images for different services (derived from container_image_* variables)"
  type        = map(string)
  default     = {}
}

# Keeping for backward compatibility
variable "container_image_url" {
  description = "URL of the main container image in ECR (from another repository) - DEPRECATED: use container_image_hello instead"
  type        = string
  default     = ""
}

# Kong Gateway configuration
variable "kong_enabled" {
  description = "Whether to enable Kong Gateway service"
  type        = bool
  default     = true
}

variable "direct_routing_enabled" {
  description = "Whether to enable direct routing to Hello-Service (bypassing Kong Gateway)"
  type        = bool
  default     = false
}

variable "kong_traffic_weight" {
  description = "Percentage of traffic to send through Kong Gateway (0-100)"
  type        = number
  default     = 100
}

variable "direct_traffic_weight" {
  description = "Percentage of traffic to send directly to Hello-Service (0-100)"
  type        = number
  default     = 0
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}



# Database variables are commented out since we're not using a database in our POC
/*
variable "db_name" {
  description = "Name of the database"
  type        = string
  default     = "sbxservice"
}

variable "db_username" {
  description = "Username for the database"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "db_password" {
  description = "Password for the database"
  type        = string
  sensitive   = true
  # Do not set a default value for passwords - should be provided via secure means
}
*/ 