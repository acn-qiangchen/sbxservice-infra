variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, test, prod)"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "firewall_subnet_ids" {
  description = "List of subnet IDs for Network Firewall deployment"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks"
  type        = list(string)
}

variable "public_route_tables_by_az" {
  description = "Map of availability zone to public route table IDs"
  type        = map(string)
}

variable "private_route_tables_by_az" {
  description = "Map of availability zone to private route table IDs"
  type        = map(string)
}

variable "nat_gateway_id" {
  description = "ID of the primary NAT Gateway (for backwards compatibility)"
  type        = string
}

variable "nat_gateway_ids" {
  description = "List of all NAT Gateway IDs"
  type        = list(string)
  default     = []
}

variable "nat_gateway_ids_by_az" {
  description = "Map of AZ to NAT Gateway IDs"
  type        = map(string)
  default     = {}
}

variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
} 