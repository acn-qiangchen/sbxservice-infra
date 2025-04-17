# S3 backend configuration for Terraform state
terraform {
  backend "s3" {
    # These values will be filled dynamically during initialization
    # Do not set fixed values here as they will be provided by the workflow
    bucket         = ""
    key            = ""
    region         = ""
    dynamodb_table = ""
    encrypt        = true
  }
} 