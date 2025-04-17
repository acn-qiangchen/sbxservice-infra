# SBXService Coding Conventions and Rules

This document outlines important conventions, rules, and easy-to-forget aspects of development for the SBXService project. Please refer to this guide to maintain consistency across the codebase.

## Table of Contents
- [SBXService Coding Conventions and Rules](#sbxservice-coding-conventions-and-rules)
  - [Table of Contents](#table-of-contents)
  - [Shell and Script Variables](#shell-and-script-variables)
    - [Variable Syntax](#variable-syntax)
  - [Docker and Container Operations](#docker-and-container-operations)
    - [Health Checks](#health-checks)
    - [ECS Task Definitions](#ecs-task-definitions)
  - [AWS Resources](#aws-resources)
    - [ECR Operations](#ecr-operations)
    - [ECS Exec Requirements](#ecs-exec-requirements)
  - [Terraform Standards](#terraform-standards)
    - [Required Resource Tags](#required-resource-tags)
    - [Using Variables](#using-variables)

## Shell and Script Variables

### Variable Syntax
- Use `#{VARIABLE}` syntax (not `$VARIABLE`) for variables in scripts and templates that will be processed by CI/CD or templating systems
- Example:
  ```bash
  # CORRECT
  docker tag my-image:latest ${ECR_REPO_URL}:latest
  docker push ${ECR_REPO_URL}:latest
  
  # INCORRECT
  docker tag my-image:latest $ECR_REPO_URL:latest
  docker push $ECR_REPO_URL:latest
  ```

## Docker and Container Operations

### Health Checks
- Always ensure health check commands are available in the container
- Install necessary tools in the Dockerfile before using them in health checks
- Example:
  ```dockerfile
  # Install curl for health check
  RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
  
  # Set health check
  HEALTHCHECK --interval=30s --timeout=3s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1
  ```

### ECS Task Definitions
- Health check commands in task definitions must match those in the Dockerfile
- Example:
  ```json
  "healthCheck": {
    "command": ["CMD-SHELL", "curl -f http://localhost:8080/actuator/health || exit 1"],
    "interval": 30,
    "timeout": 5,
    "retries": 3,
    "startPeriod": 60
  }
  ```

## AWS Resources

### ECR Operations
- Always verify repository name before pushing:
  ```bash
  aws ecr describe-repositories --query "repositories[].repositoryName" --output table
  ```

### ECS Exec Requirements
- Task definition must have `enableExecuteCommand: true`
- Task role must have SSM permissions
- AWS CLI and Session Manager plugin must be installed locally

## Terraform Standards

### Required Resource Tags
- All resources should have at minimum:
  - `Name` tag
  - `Environment` tag
  - `Project` tag

### Using Variables
- Use project and environment variables for resource naming
- Example: `"${var.project_name}-${var.environment}-resource-name"`

---

*This document will be updated as new conventions and rules are identified.* 