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

  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  firewall_subnet_cidrs = var.firewall_subnet_cidrs
}

# Network Firewall - using VPC outputs
module "network_firewall" {
  source = "./modules/network_firewall"

  project_name                = var.project_name
  environment                 = var.environment
  vpc_id                      = module.vpc.vpc_id
  vpc_cidr                    = var.vpc_cidr
  internet_gateway_id         = module.vpc.internet_gateway_id
  firewall_subnet_ids         = module.vpc.firewall_subnets
  public_subnet_cidrs         = module.vpc.public_subnet_cidrs
  private_subnet_cidrs        = module.vpc.private_subnet_cidrs
  public_route_tables_by_az   = module.vpc.public_route_tables_by_az
  private_route_tables_by_az  = module.vpc.private_route_tables_by_az
  firewall_route_tables_by_az = module.vpc.firewall_route_tables_by_az
  nat_gateway_id              = module.vpc.nat_gateway_id
  nat_gateway_ids             = module.vpc.nat_gateway_ids
  nat_gateway_ids_by_az       = module.vpc.nat_gateway_ids_by_az
  availability_zones          = var.availability_zones
  alb_certificate_arn         = aws_acm_certificate_validation.main.certificate_arn
}

# Security Groups
module "security_groups" {
  source = "./modules/security_groups"

  environment      = var.environment
  vpc_id           = module.vpc.vpc_id
  vpc_cidr         = var.vpc_cidr
  firewall_subnets = module.vpc.firewall_subnets
}

# App Mesh for Service Mesh
module "app_mesh" {
  source = "./modules/app_mesh"

  project_name   = var.project_name
  environment    = var.environment
  vpc_id         = module.vpc.vpc_id
  container_port = 8080
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

  # Container configuration
  container_image_url = lookup(local.container_images, "hello", "")
  container_port      = 8080
  task_cpu            = 1024
  task_memory         = 2048
  app_count           = 2

  # ACM certificate for HTTPS - use the new certificate
  acm_certificate_arn = aws_acm_certificate_validation.main.certificate_arn
  enable_https        = true

  # App Mesh integration
  service_mesh_enabled  = true
  mesh_name             = module.app_mesh.mesh_name
  virtual_node_name     = module.app_mesh.virtual_node_name
  service_discovery_arn = module.app_mesh.service_discovery_service_arn
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

output "mesh_name" {
  description = "The name of the App Mesh service mesh"
  value       = module.app_mesh.mesh_name
}

output "network_firewall_status" {
  description = "Network Firewall status details"
  value       = module.network_firewall.firewall_status
}

output "firewall_policy_id" {
  description = "ID of the Network Firewall Policy"
  value       = module.network_firewall.firewall_policy_id
}

output "network_firewall_flow_logs" {
  description = "CloudWatch Log Group for Network Firewall flow logs"
  value       = module.network_firewall.flow_log_group
}

output "network_firewall_alert_logs" {
  description = "CloudWatch Log Group for Network Firewall alert logs"
  value       = module.network_firewall.alert_log_group
}

output "network_firewall_tls_logs" {
  description = "CloudWatch Log Group for Network Firewall TLS logs"
  value       = module.network_firewall.tls_log_group
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