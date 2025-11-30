terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Comment out the S3 backend for now to use local backend for POC
  /*
  backend "s3" {
    # These values should be replaced with actual values when setting up the environment
    # bucket = "sbxservice-terraform-state"
    # key    = "terraform/state"
    # region = "us-east-1"
    # dynamodb_table = "sbxservice-terraform-lock"
  }
  */
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile != "" ? var.aws_profile : null

  default_tags {
    tags = {
      Project     = "sbxservice"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Construct container_images map from individual image variables
locals {
  container_images = merge(
    var.container_images,
    {
      for k, v in {
        hello = var.container_image_hello,
        kong  = var.container_image_kong,
      } : k => v if v != ""
    },
    var.container_image_url != "" ? { hello = var.container_image_url } : {}
  )

  # Construct domain names from AWS account ID
  domain_name     = "${var.aws_account_id}.realhandsonlabs.net"
  alb_domain_name = "alb.${var.aws_account_id}.realhandsonlabs.net"
}

# Data source for existing hosted zone
data "aws_route53_zone" "main" {
  name         = local.domain_name
  private_zone = false
}

# ACM Certificate with DNS validation
resource "aws_acm_certificate" "main" {
  domain_name       = "*.${local.domain_name}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "wildcard-${local.domain_name}"
  }
}

# DNS validation records
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}

# Certificate validation
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# VPC and Network Configuration
module "vpc" {
  source = "./modules/vpc"

  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  project_name       = var.project_name

  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}



# Security Groups
module "security_groups" {
  source = "./modules/security_groups"

  environment = var.environment
  vpc_id      = module.vpc.vpc_id
  vpc_cidr    = var.vpc_cidr
}

# RDS PostgreSQL for Kong (optional - can use ECS PostgreSQL instead)
module "rds" {
  count  = var.kong_db_enabled && var.kong_db_use_rds ? 1 : 0
  source = "./modules/rds"

  project_name    = var.project_name
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets
  database_sg_id  = module.security_groups.database_sg_id

  db_name               = var.kong_db_name
  db_username           = var.kong_db_user
  db_password           = var.kong_db_password
  db_instance_class     = var.kong_db_instance_class
  db_allocated_storage  = var.kong_db_allocated_storage
  multi_az              = var.kong_db_multi_az
  deletion_protection   = var.kong_db_deletion_protection
  skip_final_snapshot   = var.kong_db_skip_final_snapshot
}



# ECS Fargate for Spring Boot Application
module "ecs" {
  source = "./modules/ecs"

  project_name      = var.project_name
  environment       = var.environment
  region            = var.aws_region
  vpc_id            = module.vpc.vpc_id
  public_subnets    = module.vpc.public_subnets
  private_subnets   = module.vpc.private_subnets
  public_sg_id      = module.security_groups.public_sg_id
  application_sg_id = module.security_groups.application_sg_id
  database_sg_id    = module.security_groups.database_sg_id

  # Container configuration
  container_image_url = lookup(local.container_images, "hello", "")
  container_port      = 8080
  task_cpu            = 1024
  task_memory         = 2048
  app_count           = 1

  # ACM certificate for HTTPS - use the new certificate
  acm_certificate_arn = aws_acm_certificate_validation.main.certificate_arn
  enable_https        = true

  # Kong Gateway configuration
  kong_enabled   = var.kong_enabled
  kong_app_count = 1

  # Kong Database configuration
  kong_db_enabled            = var.kong_db_enabled
  kong_db_use_rds            = var.kong_db_use_rds
  kong_db_name               = var.kong_db_name
  kong_db_user               = var.kong_db_user
  kong_db_password           = var.kong_db_password
  kong_db_host               = var.kong_db_use_rds && var.kong_db_enabled ? module.rds[0].db_instance_address : ""
  kong_db_port               = var.kong_db_use_rds && var.kong_db_enabled ? module.rds[0].db_instance_port : 5432
  kong_control_plane_enabled = var.kong_control_plane_enabled

  # Direct routing configuration
  direct_routing_enabled = var.direct_routing_enabled
  kong_traffic_weight    = var.kong_traffic_weight
  direct_traffic_weight  = var.direct_traffic_weight
}

# Route53 A record for ALB custom domain
resource "aws_route53_record" "alb" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.alb_domain_name
  type    = "A"

  alias {
    name                   = module.ecs.alb_dns_name
    zone_id                = module.ecs.alb_zone_id
    evaluate_target_health = true
  }
}

# API Gateway
module "api_gateway" {
  source = "./modules/api_gateway"

  project_name    = var.project_name
  environment     = var.environment
  public_subnets  = module.vpc.public_subnets
  public_sg_id    = module.security_groups.public_sg_id
  lb_listener_arn = module.ecs.lb_listener_arn
  alb_dns_name    = local.alb_domain_name
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/sbxservice/${var.environment}"
  retention_in_days = 30

  tags = {
    Name = "sbxservice-${var.environment}-logs"
  }
}

# Outputs
output "api_gateway_endpoint" {
  description = "The API Gateway endpoint URL"
  value       = module.api_gateway.api_endpoint
}

output "alb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = module.ecs.alb_dns_name
}





# Output container images being used
output "container_images" {
  description = "Map of container images being used for each service"
  value       = local.container_images
}

# Certificate and domain outputs
output "certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = aws_acm_certificate_validation.main.certificate_arn
}

output "domain_name" {
  description = "Base domain name"
  value       = local.domain_name
}

output "alb_custom_domain" {
  description = "Custom domain name for the ALB"
  value       = local.alb_domain_name
}

output "alb_custom_domain_url" {
  description = "HTTPS URL for the ALB custom domain"
  value       = "https://${local.alb_domain_name}"
}

# Kong Gateway outputs
output "kong_nlb_dns_name" {
  description = "DNS name of the Kong Gateway Network Load Balancer"
  value       = module.ecs.kong_nlb_dns_name
}

output "kong_service_name" {
  description = "Name of the Kong Gateway ECS service"
  value       = module.ecs.kong_service_name
}

output "kong_enabled" {
  description = "Whether Kong Gateway is enabled"
  value       = var.kong_enabled
}

# Direct routing outputs
output "direct_routing_enabled" {
  description = "Whether direct routing is enabled"
  value       = var.direct_routing_enabled
}

output "direct_nlb_dns_name" {
  description = "DNS name of the Direct Network Load Balancer"
  value       = module.ecs.direct_nlb_dns_name
}

output "traffic_routing_weights" {
  description = "Current traffic routing weights"
  value = {
    kong_weight   = var.kong_traffic_weight
    direct_weight = var.direct_traffic_weight
  }
}

# Service Discovery outputs
output "service_discovery_namespace" {
  description = "Service discovery namespace name"
  value       = module.ecs.service_discovery_namespace_name
}

output "hello_service_dns_name" {
  description = "DNS name for hello-service discovery"
  value       = "${var.project_name}.${module.ecs.service_discovery_namespace_name}"
}

output "kong_service_dns_name" {
  description = "DNS name for Kong Gateway service discovery"
  value       = var.kong_enabled ? "kong-gateway.${module.ecs.service_discovery_namespace_name}" : null
}

# Kong Control Plane and Database outputs
output "postgres_dns_name" {
  description = "DNS name for PostgreSQL service discovery"
  value       = module.ecs.postgres_dns_name
}

output "kong_cp_dns_name" {
  description = "DNS name for Kong Control Plane service discovery"
  value       = module.ecs.kong_cp_dns_name
}

output "kong_admin_api_endpoint" {
  description = "Kong Admin API endpoint URL for management"
  value       = module.ecs.kong_admin_api_endpoint
}

output "kong_admin_nlb_dns_name" {
  description = "DNS name of the Kong Admin API Network Load Balancer"
  value       = module.ecs.kong_admin_nlb_dns_name
}

# RDS outputs
output "kong_db_endpoint" {
  description = "Kong RDS database endpoint"
  value       = var.kong_db_use_rds && var.kong_db_enabled ? module.rds[0].db_instance_endpoint : null
}

output "kong_db_address" {
  description = "Kong RDS database address"
  value       = var.kong_db_use_rds && var.kong_db_enabled ? module.rds[0].db_instance_address : null
}

output "kong_db_type" {
  description = "Kong database type (RDS or ECS)"
  value       = var.kong_db_use_rds ? "RDS PostgreSQL" : "ECS PostgreSQL Container"
} 