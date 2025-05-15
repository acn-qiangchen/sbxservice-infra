# S3 backend configuration for Terraform state
# This uses partial configuration which allows different environments to specify their own backend values
# For local development, you can use: terraform init -backend=false
# For production, use: terraform init -backend-config=backend.hcl
terraform {
  backend "s3" {
    encrypt        = true
    # These values will be filled dynamically during initialization using -backend-config
    # DO NOT set fixed values here as they will be provided during terraform init
    # Example command: terraform init -backend-config="bucket=sbxservice-terraform-state" -backend-config="key=terraform/state" -backend-config="region=us-east-1" -backend-config="dynamodb_table=sbxservice-terraform-lock"
  }
} 