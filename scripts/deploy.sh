#!/bin/bash
# Deployment script for SBXService microservices

set -e # Exit on error

# Required environment variables:
# - AWS_REGION: AWS region to deploy to
# - ENVIRONMENT: Deployment environment (dev, test, prod)
# - SERVICE_NAME: Name of the service to deploy
# - IMAGE_TAG: Docker image tag to deploy

# Default values
AWS_REGION=${AWS_REGION:-us-east-1}
ENVIRONMENT=${ENVIRONMENT:-dev}
IMAGE_TAG=${IMAGE_TAG:-latest}

# Check for required environment variables
if [ -z "$SERVICE_NAME" ]; then
    echo "Error: SERVICE_NAME is required"
    exit 1
fi

echo "=== Starting deployment of $SERVICE_NAME to $ENVIRONMENT environment ==="
echo "AWS Region: $AWS_REGION"
echo "Image Tag: $IMAGE_TAG"

# Validate AWS CLI configuration
if ! aws configure list > /dev/null 2>&1; then
    echo "Error: AWS CLI is not configured properly"
    exit 1
fi

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
echo "AWS Account ID: $AWS_ACCOUNT_ID"

# Set ECR repository name
ECR_REPO="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/sbxservice-$SERVICE_NAME"
FULL_IMAGE_NAME="$ECR_REPO:$IMAGE_TAG"

echo "=== Logging in to Amazon ECR ==="
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

echo "=== Using image: $FULL_IMAGE_NAME ==="

# Update ECS service (if using ECS)
if [ "$DEPLOYMENT_TYPE" = "ecs" ]; then
    echo "=== Updating ECS service ==="
    CLUSTER_NAME="sbxservice-$ENVIRONMENT"
    SERVICE_NAME="sbxservice-$ENVIRONMENT-$SERVICE_NAME"
    
    # Get the current task definition
    TASK_DEFINITION=$(aws ecs describe-task-definition --task-definition $SERVICE_NAME --region $AWS_REGION)
    
    # Create new task definition with updated image
    NEW_TASK_DEFINITION=$(echo $TASK_DEFINITION | jq --arg IMAGE "$FULL_IMAGE_NAME" '.taskDefinition | .containerDefinitions[0].image = $IMAGE | {family: .family, volumes: .volumes, containerDefinitions: .containerDefinitions, taskRoleArn: .taskRoleArn, executionRoleArn: .executionRoleArn, networkMode: .networkMode, placementConstraints: .placementConstraints, requiresCompatibilities: .requiresCompatibilities, cpu: .cpu, memory: .memory}')
    
    # Register the new task definition
    NEW_TASK_DEF_ARN=$(aws ecs register-task-definition --region $AWS_REGION --cli-input-json "$NEW_TASK_DEFINITION" --query 'taskDefinition.taskDefinitionArn' --output text)
    
    echo "=== New task definition: $NEW_TASK_DEF_ARN ==="
    
    # Update the service with the new task definition
    aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --task-definition $NEW_TASK_DEF_ARN --region $AWS_REGION
    
    echo "=== Waiting for service to stabilize ==="
    aws ecs wait services-stable --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $AWS_REGION
fi

# Update Kubernetes deployment (if using EKS)
if [ "$DEPLOYMENT_TYPE" = "eks" ]; then
    echo "=== Updating Kubernetes deployment ==="
    CLUSTER_NAME="sbxservice-$ENVIRONMENT"
    
    # Update kubeconfig
    aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION
    
    # Update the deployment image
    kubectl set image deployment/$SERVICE_NAME $SERVICE_NAME=$FULL_IMAGE_NAME -n sbxservice
    
    # Wait for rollout to complete
    kubectl rollout status deployment/$SERVICE_NAME -n sbxservice
fi

# Update Lambda function (if using Lambda)
if [ "$DEPLOYMENT_TYPE" = "lambda" ]; then
    echo "=== Updating Lambda function ==="
    FUNCTION_NAME="sbxservice-$ENVIRONMENT-$SERVICE_NAME"
    
    # Update function code
    aws lambda update-function-code --function-name $FUNCTION_NAME --image-uri $FULL_IMAGE_NAME --region $AWS_REGION
    
    # Wait for update to complete
    aws lambda wait function-updated --function-name $FUNCTION_NAME --region $AWS_REGION
fi

echo "=== Deployment of $SERVICE_NAME to $ENVIRONMENT completed successfully ==="
exit 0 