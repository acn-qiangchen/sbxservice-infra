terraform {
  required_version = ">= 1.0.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    # These values should be replaced with actual values when setting up the environment
    # bucket = "sbxservice-terraform-state"
    # key    = "terraform/state"
    # region = "us-east-1"
    # dynamodb_table = "sbxservice-terraform-lock"
  }
}

provider "aws" {
  region = var.aws_region
  
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

# ECS/EKS Cluster (commented out until needed)
# module "container_cluster" {
#   source = "./modules/container_cluster"
#   
#   environment      = var.environment
#   vpc_id           = module.vpc.vpc_id
#   private_subnets  = module.vpc.private_subnets
#   public_subnets   = module.vpc.public_subnets
# }

# RDS Database (commented out until needed)
# module "database" {
#   source = "./modules/database"
#   
#   environment     = var.environment
#   vpc_id          = module.vpc.vpc_id
#   private_subnets = module.vpc.private_subnets
#   db_name         = var.db_name
#   db_username     = var.db_username
#   db_password     = var.db_password
# }

# API Gateway
# module "api_gateway" {
#   source = "./modules/api_gateway"
#   
#   environment = var.environment
#   name        = "${var.project_name}-api"
# }

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/sbxservice/${var.environment}"
  retention_in_days = 30
  
  tags = {
    Name = "sbxservice-${var.environment}-logs"
  }
} 