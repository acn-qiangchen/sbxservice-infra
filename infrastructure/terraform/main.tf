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
  profile = "sbxservice-poc"
  
  default_tags {
    tags = {
      Project     = "sbxservice"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# VPC and Network Configuration
module "vpc" {
  source = "./modules/vpc"
  
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  azs          = var.availability_zones
  project_name = var.project_name
}

# Security Groups
module "security_groups" {
  source = "./modules/security_groups"
  
  environment = var.environment
  vpc_id      = module.vpc.vpc_id
}

# ECS Fargate for Spring Boot Application
module "ecs" {
  source = "./modules/ecs"
  
  project_name     = var.project_name
  environment      = var.environment
  region           = var.aws_region
  vpc_id           = module.vpc.vpc_id
  public_subnets   = module.vpc.public_subnets
  private_subnets  = module.vpc.private_subnets
  public_sg_id     = module.security_groups.public_sg_id
  application_sg_id = module.security_groups.application_sg_id
  
  # Container configuration
  container_port   = 8080
  task_cpu         = 256
  task_memory      = 512
  app_count        = 1
}

# API Gateway
module "api_gateway" {
  source = "./modules/api_gateway"
  
  project_name    = var.project_name
  environment     = var.environment
  public_subnets  = module.vpc.public_subnets
  public_sg_id    = module.security_groups.public_sg_id
  lb_listener_arn = module.ecs.lb_listener_arn
  alb_dns_name    = module.ecs.alb_dns_name
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
output "ecr_repository_url" {
  description = "The URL of the ECR repository"
  value       = module.ecs.ecr_repository_url
}

output "api_gateway_endpoint" {
  description = "The API Gateway endpoint URL"
  value       = module.api_gateway.api_endpoint
}

output "alb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = module.ecs.alb_dns_name
} 