# S3 backend configuration for Terraform state
terraform {
  # backend "s3" {
  #   # These values will be filled dynamically during initialization
  #   # Do not set fixed values here as they will be provided by the workflow
  #   bucket         = ""
  #   key            = ""
  #   region         = ""
  #   dynamodb_table = ""
  #   encrypt        = true
  # }
    backend "s3" {
    # These values will be filled dynamically during initialization
    # Do not set fixed values here as they will be provided by the workflow
    bucket         = "sbxservice-terraform-state-891376925337"
    key            = "environments/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "sbxservice-terraform-locks-891376925337"
    encrypt        = true
  }
} 