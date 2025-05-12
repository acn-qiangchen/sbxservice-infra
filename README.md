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

For architecture details, see [POC Architecture](docs/poc_architecture.md).

## Project Structure

```
.
├── docs/                    # Documentation
│   └── architecture/        # Architecture diagrams and documents
├── terraform/               # Terraform code for AWS infrastructure
│   ├── modules/             # Reusable Terraform modules
│   │   ├── api_gateway/     # API Gateway module
│   │   ├── ecs/             # ECS module
│   │   ├── security_groups/ # Security groups module
│   │   └── vpc/             # VPC module
│   ├── main.tf              # Main Terraform configuration
│   └── variables.tf         # Terraform variables
```

## Application Services

The application services are now maintained in a separate repository: [SBXService Applications](https://github.com/your-org/sbxservice-apps).

## Prerequisites

- AWS CLI installed and configured with appropriate credentials
- Terraform 1.0.0 or later
- Docker installed for building container images

## Local Development Configuration

1. Set up your AWS CLI profile:

```bash
# List existing profiles (if any)
aws configure list-profiles

# Configure your AWS credentials
aws configure --profile your-aws-profile
# Enter your AWS Access Key ID, Secret Access Key, default region, and output format when prompted

# Set the profile globally for your current terminal session
export AWS_PROFILE=your-aws-profile

# Verify which AWS account is currently active (do this before running Terraform)
aws sts get-caller-identity
```

2. Create a `terraform.tfvars` file from the example:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

3. Edit the `terraform.tfvars` file to match your local configuration:

```bash
# Set your AWS profile and other settings
aws_profile = "your-aws-profile"
```

## Deploying Infrastructure

1. Initialize Terraform:

```bash
cd terraform
terraform init
```

2. Review the execution plan:

```bash
# For local development with AWS profile:
terraform plan

# For CI/CD or when using AWS environment variables (not profile):
terraform plan -var="aws_profile="
```

3. Apply the Terraform configuration:

```bash
# For local development with AWS profile:
terraform apply

# For CI/CD or when using AWS environment variables (not profile):
terraform apply -var="aws_profile=" -var="container_image_hello=YOUR_HELLO_SERVICE_IMAGE_URL"
```

### Container Image Management

The infrastructure currently supports one service called "hello-service" with its container image specified using the `container_image_hello` variable:

```hcl
# In terraform.tfvars or via command line
container_image_hello = "123456789012.dkr.ecr.us-east-1.amazonaws.com/hello-service:latest"
```

The architecture is designed to be extended in the future to support multiple services by adding additional container image variables with appropriate suffixes.

After successful application, Terraform will output:
- ALB hostname
- API Gateway endpoint URL
- Container images being used

## Network Firewall Architecture

The deployment includes AWS Network Firewall for enhanced security:

- Dedicated public firewall subnets in each availability zone
- Network Firewall with inspection of traffic between Internet Gateway and public subnets
- Custom Suricata-compatible rules for traffic inspection
- No stateless rules or TLS inspection
- Traffic routing through firewall endpoints for traffic from Internet Gateway to ALB
- Traffic routing through firewall endpoints for traffic from ALB to ECS services
- Secure return path for traffic from private subnets back to public subnets

The Network Firewall is positioned at the edge of the VPC to inspect all incoming traffic before it reaches the ALB, providing an additional layer of protection for your application.

### Handling Route Conflicts

When deploying the Network Firewall with edge routing, you might encounter route conflicts with AWS default local routes. If you see errors like `RouteAlreadyExists`, you may need to manually delete conflicting routes before applying Terraform:

```bash
# List route tables to find the route table ID
aws ec2 describe-route-tables --filters "Name=tag:Name,Values=*igw-edge*" --query "RouteTables[*].{ID:RouteTableId, Name:Tags[?Key=='Name'].Value|[0]}"

# Delete the conflicting route
aws ec2 delete-route --route-table-id <rtb-id> --destination-cidr-block <vpc-cidr>
```

## Building and Deploying Applications

**Important:** The ECR resources have been moved to a separate repository. When building and deploying applications, ensure you:

1. Build your application using the appropriate external ECR repository
2. Provide the container image URL when applying Terraform using the appropriate container_image_* variable
3. Tag and push your images to the external ECR repository

When building container images, especially on Apple Silicon (M1/M2 Macs), you must specify the target platform for compatibility with AWS Fargate:

```bash
# IMPORTANT: When building on Apple Silicon (M1/M2 Macs), you must specify the target platform
docker buildx build --platform linux/amd64 -t your-image-name .
```

## Monitoring ECS Services

After deploying your application, you can check the status of your ECS services using the following commands:

```bash
# List all ECS clusters in your account
aws ecs list-clusters

# View running services in a cluster
aws ecs list-services --cluster sbxservice-dev-cluster

# View container logs in CloudWatch
aws logs get-log-events --log-group-name /ecs/sbxservice-dev --log-stream-name ecs/container/STREAM_SUFFIX
```

For debugging, you can use ECS Exec to connect directly to running containers:

```bash
# Get a task ID
TASK_ID=$(aws ecs list-tasks --cluster sbxservice-dev-cluster --service-name sbxservice-dev-service --query 'taskArns[0]' --output text | cut -d'/' -f3)

# Execute an interactive shell
aws ecs execute-command --cluster sbxservice-dev-cluster \
                       --task $TASK_ID \
                       --container sbxservice-dev-container \
                       --interactive \
                       --command "/bin/sh"
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

If you encounter an error like:
```
CannotPullContainerError: pull image manifest has been retried 5 time(s): image Manifest does not contain descriptor matching platform 'linux/amd64'
```

This is due to a platform mismatch between your build environment (especially on Apple Silicon Macs) and AWS Fargate.

## Clean Up

To destroy all AWS resources:

```bash
cd terraform
terraform destroy
```
