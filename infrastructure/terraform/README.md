# SBXService POC Terraform Configuration

This directory contains Terraform configuration to deploy the SBXService POC architecture on AWS.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) installed (version >= 1.2.0)
- AWS CLI installed and configured with appropriate credentials
- Docker installed for building the Spring Boot container image

## Architecture Components

The Terraform configuration creates the following AWS resources:

- VPC with public and private subnets
- Network Firewall for enhanced security
- Security groups
- ECR repository for the container image
- ECS cluster with Fargate launch type
- ECS task definition and service
- Application Load Balancer
- REST API Gateway
- AWS App Mesh for service mesh capabilities
- CloudWatch Logs
- IAM roles and policies

## Network Firewall Architecture

The deployment includes AWS Network Firewall for enhanced security:

- Dedicated firewall subnets in each availability zone
- Network Firewall with inspection of traffic between public and private subnets
- Custom Suricata-compatible rules for traffic inspection
- No stateless rules or TLS inspection
- Traffic routing through firewall endpoints for traffic from ALB to ECS services
- Secure return path for traffic from private subnets back to public subnets

The Network Firewall allows fine-grained control over north-south traffic flow and provides:
- Deep packet inspection with Suricata-compatible rule syntax
- HTTP protocol compliance checking
- SQL injection attack detection
- Malicious user agent blocking
- Suspicious IP range filtering

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

# Alternatively, you can set individual AWS environment variables:
# export AWS_ACCESS_KEY_ID=your_access_key
# export AWS_SECRET_ACCESS_KEY=your_secret_key
# export AWS_REGION=your_region
```

2. Create a `terraform.tfvars` file from the example:

```bash
cp terraform.tfvars.example terraform.tfvars
```

3. Edit the `terraform.tfvars` file to match your local configuration:

```bash
# Set your AWS profile and other settings
aws_profile = "your-aws-profile"
```

4. When switching between AWS accounts, clean up previous Terraform state:

```bash
# Remove the local Terraform state files
rm -f terraform.tfstate terraform.tfstate.backup

# Remove the .terraform directory that contains provider configurations
# rm -rf .terraform/

# Reinitialize Terraform with the new account configuration
terraform init
```

## CI/CD Configuration

The project uses separate GitHub Actions workflows for service deployments and Terraform operations:

### 1. Service CI/CD Workflow (.github/workflows/ci-cd.yml)
- Triggered when service code changes
- Builds Java applications, creates Docker images, and pushes to ECR
- Forces new ECS deployments with the updated images

### 2. Terraform Workflow (.github/workflows/terraform.yml)
- Triggered when infrastructure code changes
- Runs `terraform plan` automatically on changes
- Applies Terraform changes only when manually triggered with the 'apply' action
- Provides options for planning, applying, or destroying infrastructure
- Infrastructure changes require explicit approval via the GitHub Actions UI

For both workflows, AWS credentials are provided via GitHub Secrets, not AWS profiles.

## Usage

### Terraform Commands

1. Initialize Terraform and download required providers:

```bash
terraform init
```

2. Review the execution plan:

```bash
# For local development with AWS profile:
terraform plan

# For CI/CD or when using AWS environment variables (not profile):
terraform plan -var="aws_profile="
```

3. Apply the configuration:

```bash
# For local development with AWS profile:
terraform apply

# For CI/CD or when using AWS environment variables (not profile):
terraform apply -var="aws_profile="
```

4. View the current state:

```bash
terraform show
```

5. List all resources managed by Terraform:

```bash
terraform state list
```

6. View outputs defined in the configuration:

```bash
terraform output
```

7. Destroy all resources (use with caution):

```bash
terraform destroy
```

8. Format Terraform configuration files:

```bash
terraform fmt
```

9. Validate Terraform configuration:

```bash
terraform validate
```

After successful application, Terraform will output:
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

## Hello World Service Integration

The infrastructure is designed to host the Hello World microservice located in `services/hello-service`. This service is:

1. **Technology Stack**:
   - Spring Boot 3.2.x with Java 17
   - Containerized with Docker
   - API documentation via SpringDoc OpenAPI (Swagger)

2. **Key Features**:
   - Simple REST API with a `GET /api/hello` endpoint
   - Health checks via Spring Boot Actuator
   - Containerized with multi-stage Docker build
   - Local development support with Docker Compose

3. **Terraform Integration Points**:
   - The ECS cluster will host this containerized service
   - The ECR repository will store the Docker image
   - The ALB will route traffic to this service
   - The API Gateway can be configured to expose this service's endpoints

4. **Deployment Process**:
   - Build the service using Maven (`./mvnw clean package`)
   - Build the Docker image with platform compatibility for AWS Fargate
   - Push the image to ECR (using the URL provided by Terraform output)
   - The ECS service will pick up the new image automatically

5. **Monitoring**:
   - Service health can be monitored via the `/actuator/health` endpoint
   - Basic metrics are available via Spring Boot Actuator
   - Logs are captured in CloudWatch from the container

## Monitoring ECS Services

After deploying your application, you can check the status of your ECS services using the following commands:

### List ECS Clusters

```bash
# List all ECS clusters in your account
aws ecs list-clusters

# Check details of a specific cluster (replace with your cluster name)
aws ecs describe-clusters --clusters sbxservice-dev-cluster
```

### View Running Services

```bash
# List all services in a cluster
aws ecs list-services --cluster sbxservice-dev-cluster

# Get detailed information about a service
aws ecs describe-services --cluster sbxservice-dev-cluster --services sbxservice-dev-service
```

### Check Tasks and Containers

```bash
# List running tasks in a cluster
aws ecs list-tasks --cluster sbxservice-dev-cluster

# Get details of a specific task (replace TASK_ID with an actual task ID)
aws ecs describe-tasks --cluster sbxservice-dev-cluster --tasks TASK_ID

# View task definition details
aws ecs describe-task-definition --task-definition sbxservice-dev-task-definition
```

### View Service Events and Logs

```bash
# View recent service events (from describe-services output)
aws ecs describe-services --cluster sbxservice-dev-cluster --services sbxservice-dev-service --query 'services[0].events'

# View CloudWatch logs (get log group and stream names from task definition and describe-tasks)
aws logs get-log-events --log-group-name /ecs/sbxservice-dev --log-stream-name ecs/container/STREAM_SUFFIX
```

### Execute Commands in a Running Container

For debugging and troubleshooting, you can execute commands directly inside a running container using ECS Exec:

```bash
# First, ensure your task execution role has the required permissions for SSM
# Then, get a task ID
TASK_ID=$(aws ecs list-tasks --cluster sbxservice-dev-cluster --service-name sbxservice-dev-service --query 'taskArns[0]' --output text | cut -d'/' -f3)

# Execute an interactive shell in the container (sbxservice-dev-container is the container name defined in task definition)
aws ecs execute-command --cluster sbxservice-dev-cluster \
                         --task $TASK_ID \
                         --container sbxservice-dev-container \
                         --interactive \
                         --command "/bin/sh"

# Or run a specific command
aws ecs execute-command --cluster sbxservice-dev-cluster \
                         --task $TASK_ID \
                         --container sbxservice-dev-container \
                         --interactive \
                         --command "ls -la /app"
```

**Note:** ECS Exec requires:
1. AWS CLI version 1.22.3 or higher with Session Manager plugin installed
2. Task definition with `enableExecuteCommand: true` setting
3. IAM permissions for SSM on the task execution role

#### Installing the Session Manager Plugin

If you see the error `SessionManagerPlugin is not found`, you need to install the AWS Session Manager plugin:

**macOS (using Homebrew):**
```bash
brew install --cask session-manager-plugin
```

**macOS (manual installation):**
```bash
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/mac/sessionmanager-bundle.zip" -o "sessionmanager-bundle.zip"
unzip sessionmanager-bundle.zip
sudo ./sessionmanager-bundle/install -i /usr/local/sessionmanagerplugin -b /usr/local/bin/session-manager-plugin
```

**Linux (Ubuntu/Debian):**
```bash
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
sudo dpkg -i session-manager-plugin.deb
```

**Windows:**
```
Download and run the installer:
https://s3.amazonaws.com/session-manager-downloads/plugin/latest/windows/SessionManagerPluginSetup.exe
```

Verify installation:
```bash
session-manager-plugin --version
```

#### Enabling Execute Command in Task Definition

If you encounter the error `execute command was not enabled when the task was run`, you need to enable the execute command capability in your task definition. Add the following to your Terraform configuration:

1. Update your ECS service in `modules/ecs/main.tf`:

```terraform
resource "aws_ecs_service" "app" {
  # ... existing configuration ...
  
  enable_execute_command = true
  
  # ... rest of configuration ...
}
```

2. Ensure your task execution role has the necessary permissions by adding this policy:

```terraform
resource "aws_iam_policy" "ecs_exec_policy" {
  name        = "${var.project_name}-${var.environment}-ecs-exec-policy"
  description = "Allow ECS Exec for task debugging"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "task_exec_policy" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_exec_policy.arn
}
```

3. Apply the changes and redeploy your service:

```bash
terraform apply
aws ecs update-service --cluster sbxservice-dev-cluster --service sbxservice-dev-service --force-new-deployment
```

After the new tasks are running, you should be able to use the execute-command functionality.

If ECS Exec is not available, you can view logs as an alternative:

```bash
# Get the most recent logs
aws logs get-log-events --log-group-name /ecs/sbxservice-dev --log-stream-name $(aws logs describe-log-streams --log-group-name /ecs/sbxservice-dev --order-by LastEventTime --descending --limit 1 --query 'logStreams[0].logStreamName' --output text)
```

### Health Check

```bash
# Get the ALB DNS name (if using Terraform)
ALB_DNS=$(terraform output -raw alb_dns_name)

# Check the application health endpoint
curl -v http://$ALB_DNS/actuator/health
```

