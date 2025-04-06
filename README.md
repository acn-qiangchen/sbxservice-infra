# SBXService POC

A simple Spring Boot Hello World application deployed on AWS ECS Fargate with API Gateway.

## Architecture

This POC implements a minimal architecture with the following components:

- Spring Boot service running on AWS ECS Fargate
- Amazon API Gateway for API access
- AWS Application Load Balancer
- Amazon CloudWatch for basic monitoring

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
├── services/                     # Service directories
│   └── hello-service/            # Spring Boot Hello World service
├── src/                          # Spring Boot application source code
└── Dockerfile                    # Docker configuration for containerization
```

## Getting Started

### Prerequisites

- Java 17 or later
- Maven 3.8 or later
- Docker
- AWS CLI configured with appropriate credentials
- Terraform 1.0.0 or later

### Building the Application

1. Build the Spring Boot application:

```bash
cd services/hello-service
./mvnw clean package
```

2. Build the Docker image:

```bash
# IMPORTANT: When building on Apple Silicon (M1/M2 Macs), you must specify the target platform
# for compatibility with AWS Fargate which uses x86/amd64
docker buildx build --platform linux/amd64 -t hello-service .

# On Intel/AMD machines, you can use the standard build command
# docker build -t hello-service .
```

### Deploying to AWS

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

3. After successful deployment, get the ECR repository URL:

```bash
export ECR_REPO_URL=$(terraform output -raw ecr_repository_url)
```

4. Tag and push your Docker image:

```bash
# Make sure to use the correct AWS profile
aws ecr get-login-password --region us-east-1 --profile your-aws-profile | docker login --username AWS --password-stdin $ECR_REPO_URL
docker tag hello-service:latest $ECR_REPO_URL:latest
docker push $ECR_REPO_URL:latest
```

5. Access your API via the API Gateway URL:

```bash
echo "API Gateway URL: $(terraform output -raw api_gateway_endpoint)"
```

## Common Issues and Troubleshooting

### Platform Compatibility Issues

If you encounter an error like:
```
CannotPullContainerError: pull image manifest has been retried 5 time(s): image Manifest does not contain descriptor matching platform 'linux/amd64'
```

This is due to a platform mismatch between your build environment (especially on Apple Silicon Macs) and AWS Fargate, which uses x86/amd64 architecture. Ensure you build your Docker image with the correct platform flag:

```bash
docker buildx build --platform linux/amd64 -t hello-service .
```

## Clean Up

To destroy all AWS resources created for this POC:

```bash
cd infrastructure/terraform
terraform destroy
```
