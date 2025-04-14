# SBXService Infrastructure

This repository contains the infrastructure code for deploying the SBXService platform on AWS. It uses Terraform to provision and manage AWS resources including ECS Fargate, App Mesh, Network Firewall, and API Gateway.

## Architecture

This infrastructure implements a minimal architecture with the following components:

- AWS ECS Fargate for container orchestration
- Amazon API Gateway for API access
- AWS Application Load Balancer
- AWS App Mesh for service mesh capabilities
- AWS Network Firewall for security
- Amazon CloudWatch for monitoring

For architecture details, see [POC Architecture](docs/architecture/poc_architecture.md).

## Project Structure

```
.
├── docs/                         # Documentation
│   └── architecture/             # Architecture diagrams and documents
├── infrastructure/               # Terraform code for AWS infrastructure
│   └── terraform/
│       ├── modules/              # Reusable Terraform modules
│       │   ├── api_gateway/      # API Gateway module
│       │   ├── ecs/              # ECS and ECR module
│       │   ├── security_groups/  # Security groups module
│       │   └── vpc/              # VPC module
│       ├── main.tf               # Main Terraform configuration
│       └── variables.tf          # Terraform variables
```

## Application Services

The application services are now maintained in a separate repository: [SBXService Applications](https://github.com/your-org/sbxservice-apps).

## Getting Started

### Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform 1.0.0 or later

### Deploying Infrastructure

1. Initialize Terraform:

```bash
cd infrastructure/terraform
terraform init
```

2. Apply the Terraform configuration:

```bash
# Make sure to specify the correct AWS profile
terraform apply
```

## Common Issues and Troubleshooting

### AWS Profile

When executing AWS CLI commands, always check if AWS_PROFILE environment variable exists. If AWS_PROFILE does not exist, set it:

```bash
export AWS_PROFILE=your-profile-name
```

### Platform Compatibility

When building Docker images, always set the `platform` flag to the appropriate value for AWS Fargate:

```bash
docker buildx build --platform linux/amd64 -t your-service .
```

## Clean Up

To destroy all AWS resources:

```bash
cd infrastructure/terraform
terraform destroy
```
