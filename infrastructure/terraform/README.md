# SBXService POC Terraform Configuration

This directory contains Terraform configuration to deploy the SBXService POC architecture on AWS.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) installed (version >= 1.2.0)
- AWS CLI installed and configured with appropriate credentials
- Docker installed for building the Spring Boot container image

## Architecture Components

The Terraform configuration creates the following AWS resources:

- VPC with public subnets
- Security groups
- ECR repository for the container image
- ECS cluster with Fargate launch type
- ECS task definition and service
- Application Load Balancer
- API Gateway (HTTP API)
- CloudWatch Logs
- IAM roles and policies

## Usage

1. Initialize Terraform:

```bash
terraform init
```

2. Review the execution plan:

```bash
# Make sure to use the correct AWS profile
terraform plan
```

3. Apply the configuration:

```bash
# Make sure to use the correct AWS profile
terraform apply
```

4. After successful application, Terraform will output:
   - ECR repository URL for pushing your Docker image
   - ALB hostname
   - API Gateway endpoint URL

## Building and Deploying the Spring Boot Application

1. Build your Spring Boot application:

```bash
./mvnw clean package
```

2. Build the Docker image:

```bash
# IMPORTANT: When building on Apple Silicon (M1/M2 Macs), you must specify the target platform
# for compatibility with AWS Fargate which uses x86/amd64
docker buildx build --platform linux/amd64 -t spring-boot-app .

# On Intel/AMD machines, you can use the standard build command
# docker build -t spring-boot-app .
```

3. Tag and push the image to ECR (use the ECR repository URL from Terraform output):

```bash
# Make sure to use the correct AWS profile
aws ecr get-login-password --region us-east-1 --profile your-aws-profile | docker login --username AWS --password-stdin YOUR_ECR_REPO_URL
docker tag spring-boot-app:latest YOUR_ECR_REPO_URL:latest
docker push YOUR_ECR_REPO_URL:latest
```

4. The ECS service will automatically deploy the new image.

## Troubleshooting

### Platform Compatibility Issues

If you encounter an error like:
```
CannotPullContainerError: pull image manifest has been retried 5 time(s): image Manifest does not contain descriptor matching platform 'linux/amd64'
```

This is due to a platform mismatch between your build environment (especially on Apple Silicon Macs) and AWS Fargate, which uses x86/amd64 architecture. Ensure you build your Docker image with the correct platform flag as shown above.

## Clean Up

To destroy all resources created by Terraform:

```bash
# Make sure to use the correct AWS profile
terraform destroy
```

## Customization

You can modify the `variables.tf` file to customize the deployment, including:
- AWS region
- Project name
- Container specifications
- Number of container instances 