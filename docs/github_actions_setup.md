# GitHub Actions Setup Guide

## Overview

This guide explains how to set up GitHub Actions for automated Terraform deployments to AWS.

## Prerequisites

1. GitHub repository with this code
2. AWS account with appropriate permissions
3. IAM role for GitHub Actions (created using `scripts/setup-github-actions-role.sh`)

## Required GitHub Secrets

You need to configure the following secrets in your GitHub repository:

### Navigation
Go to: **GitHub Repository → Settings → Secrets and variables → Actions → New repository secret**

### Required Secrets

#### 1. AWS_ACCOUNT_ID
- **Description**: Your AWS account ID
- **How to get it**:
  ```bash
  aws sts get-caller-identity --query Account --output text
  ```
- **Example**: `123456789012`

#### 2. AWS_REGION
- **Description**: AWS region for deployment
- **Value**: `us-east-1` (or your preferred region)

#### 3. CONTAINER_IMAGE_HELLO
- **Description**: ECR URL for hello-service container image
- **Format**: `{ACCOUNT_ID}.dkr.ecr.{REGION}.amazonaws.com/{REPO_NAME}:{TAG}`
- **Example**: `123456789012.dkr.ecr.us-east-1.amazonaws.com/sbxservice-hello-service:latest`
- **How to get it**:
  ```bash
  # List ECR repositories
  aws ecr describe-repositories --query 'repositories[*].[repositoryName,repositoryUri]' --output table
  
  # Get specific repository URI
  aws ecr describe-repositories --repository-names sbxservice-hello-service --query 'repositories[0].repositoryUri' --output text
  ```

#### 4. KONG_DB_PASSWORD
- **Description**: Password for Kong PostgreSQL database
- **Requirements**: 
  - Minimum 8 characters
  - Mix of letters, numbers, and special characters
  - Keep it secure!
- **Example**: `MySecureKongPassword123!`
- **⚠️ Important**: Use a strong, unique password

#### 5. TF_VAR_kong_db_password (Optional but Recommended)
- **Description**: Alternative way to pass Kong DB password to Terraform
- **Value**: Same as KONG_DB_PASSWORD
- **Note**: This follows Terraform's environment variable convention

## Step-by-Step Setup

### Step 1: Create IAM Role for GitHub Actions

Run the setup script to create the necessary IAM role:

```bash
cd scripts

# Run the setup script
./setup-github-actions-role.sh -a YOUR_AWS_ACCOUNT_ID

# Follow the prompts to:
# 1. Enter AWS credentials
# 2. Create OIDC provider
# 3. Create IAM role with AdministratorAccess
```

This creates:
- OIDC provider for GitHub Actions
- IAM role: `github-actions-role`
- Trust policy allowing your GitHub repository to assume the role

### Step 2: Configure GitHub Secrets

#### Option A: Using GitHub Web UI

1. Go to your repository on GitHub
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret:

```
Name: AWS_ACCOUNT_ID
Value: 123456789012

Name: AWS_REGION
Value: us-east-1

Name: CONTAINER_IMAGE_HELLO
Value: 123456789012.dkr.ecr.us-east-1.amazonaws.com/sbxservice-hello-service:latest

Name: KONG_DB_PASSWORD
Value: YourSecurePassword123!
```

#### Option B: Using GitHub CLI

```bash
# Install GitHub CLI if not already installed
# https://cli.github.com/

# Authenticate
gh auth login

# Set secrets
gh secret set AWS_ACCOUNT_ID --body "123456789012"
gh secret set AWS_REGION --body "us-east-1"
gh secret set CONTAINER_IMAGE_HELLO --body "123456789012.dkr.ecr.us-east-1.amazonaws.com/sbxservice-hello-service:latest"
gh secret set KONG_DB_PASSWORD --body "YourSecurePassword123!"
```

### Step 3: Verify GitHub Actions Workflow

The workflow file is located at `.github/workflows/terraform.yml`. It should contain:

```yaml
name: 'Terraform'

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]

permissions:
  id-token: write
  contents: read

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/github-actions-role
          aws-region: ${{ secrets.AWS_REGION }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2

      - name: Terraform Init
        run: terraform init
        working-directory: ./terraform

      - name: Terraform Plan
        run: |
          terraform plan \
            -var="aws_account_id=${{ secrets.AWS_ACCOUNT_ID }}" \
            -var="aws_region=${{ secrets.AWS_REGION }}" \
            -var="container_image_hello=${{ secrets.CONTAINER_IMAGE_HELLO }}" \
            -var="kong_db_password=${{ secrets.KONG_DB_PASSWORD }}"
        working-directory: ./terraform
```

### Step 4: Test the Setup

#### Test 1: Verify Secrets

```bash
# List configured secrets (won't show values)
gh secret list
```

Expected output:
```
AWS_ACCOUNT_ID          Updated 2024-01-01
AWS_REGION             Updated 2024-01-01
CONTAINER_IMAGE_HELLO  Updated 2024-01-01
KONG_DB_PASSWORD       Updated 2024-01-01
```

#### Test 2: Trigger Workflow

```bash
# Create a test commit
git add .
git commit -m "test: trigger GitHub Actions"
git push origin main
```

#### Test 3: Monitor Workflow

1. Go to **GitHub Repository → Actions**
2. Click on the latest workflow run
3. Monitor the steps:
   - ✅ Checkout
   - ✅ Configure AWS credentials
   - ✅ Setup Terraform
   - ✅ Terraform Init
   - ✅ Terraform Plan

## Workflow Behavior

### On Pull Request
- Runs `terraform plan`
- Shows what changes will be made
- Does NOT apply changes
- Adds plan output as PR comment

### On Push to Main/Master
- Runs `terraform plan`
- Optionally runs `terraform apply` (if configured)
- Deploys infrastructure changes

## Environment Variables in Workflow

The workflow uses these environment variables:

| Variable | Source | Purpose |
|----------|--------|---------|
| `AWS_ACCOUNT_ID` | GitHub Secret | AWS account identification |
| `AWS_REGION` | GitHub Secret | Deployment region |
| `CONTAINER_IMAGE_HELLO` | GitHub Secret | Hello service container image |
| `KONG_DB_PASSWORD` | GitHub Secret | Kong database password |

These are passed to Terraform as `-var` flags.

## Troubleshooting

### Error: "No valid credential sources found"

**Cause**: AWS credentials not configured properly

**Solution**:
1. Verify IAM role exists:
   ```bash
   aws iam get-role --role-name github-actions-role
   ```
2. Check OIDC provider:
   ```bash
   aws iam list-open-id-connect-providers
   ```
3. Verify GitHub secrets are set:
   ```bash
   gh secret list
   ```

### Error: "AccessDenied"

**Cause**: IAM role doesn't have sufficient permissions

**Solution**:
1. Check role policies:
   ```bash
   aws iam list-attached-role-policies --role-name github-actions-role
   ```
2. Verify trust policy allows your repository:
   ```bash
   aws iam get-role --role-name github-actions-role --query 'Role.AssumeRolePolicyDocument'
   ```

### Error: "Image not found"

**Cause**: Container image doesn't exist or wrong URL

**Solution**:
1. Verify ECR repository exists:
   ```bash
   aws ecr describe-repositories --repository-names sbxservice-hello-service
   ```
2. Check if image exists:
   ```bash
   aws ecr list-images --repository-name sbxservice-hello-service
   ```
3. Update GitHub secret with correct image URL

### Error: "Backend initialization required"

**Cause**: Terraform state not initialized

**Solution**:
1. Check if S3 backend is configured in `backend.tf`
2. If using S3 backend, ensure bucket exists:
   ```bash
   aws s3 ls s3://your-terraform-state-bucket
   ```
3. Or use local backend for testing (comment out S3 backend in `backend.tf`)

## Security Best Practices

### 1. Least Privilege IAM Role

Instead of `AdministratorAccess`, create a custom policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "ecs:*",
        "elasticloadbalancing:*",
        "rds:*",
        "secretsmanager:*",
        "logs:*",
        "iam:PassRole"
      ],
      "Resource": "*"
    }
  ]
}
```

### 2. Restrict Repository Access

Update the trust policy to allow only your specific repository:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/YOUR_REPO:*"
        }
      }
    }
  ]
}
```

### 3. Rotate Secrets Regularly

```bash
# Update Kong DB password
gh secret set KONG_DB_PASSWORD --body "NewSecurePassword456!"

# Update in AWS Secrets Manager too
aws secretsmanager update-secret \
  --secret-id sbxservice-dev-kong-db-password \
  --secret-string "NewSecurePassword456!"
```

### 4. Enable Branch Protection

1. Go to **Settings → Branches**
2. Add branch protection rule for `main`
3. Enable:
   - Require pull request reviews
   - Require status checks to pass
   - Require branches to be up to date

## Advanced Configuration

### Auto-Apply on Main Branch

To automatically apply changes on push to main:

```yaml
- name: Terraform Apply
  if: github.ref == 'refs/heads/main' && github.event_name == 'push'
  run: |
    terraform apply -auto-approve \
      -var="aws_account_id=${{ secrets.AWS_ACCOUNT_ID }}" \
      -var="aws_region=${{ secrets.AWS_REGION }}" \
      -var="container_image_hello=${{ secrets.CONTAINER_IMAGE_HELLO }}" \
      -var="kong_db_password=${{ secrets.KONG_DB_PASSWORD }}"
  working-directory: ./terraform
```

### Matrix Builds for Multiple Environments

```yaml
strategy:
  matrix:
    environment: [dev, staging, prod]
steps:
  - name: Terraform Plan
    run: |
      terraform plan \
        -var="environment=${{ matrix.environment }}" \
        -var="aws_account_id=${{ secrets.AWS_ACCOUNT_ID }}"
```

### Slack Notifications

```yaml
- name: Notify Slack
  if: always()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

## Complete Setup Checklist

- [ ] AWS account created
- [ ] IAM role created (`github-actions-role`)
- [ ] OIDC provider configured
- [ ] GitHub secrets configured:
  - [ ] AWS_ACCOUNT_ID
  - [ ] AWS_REGION
  - [ ] CONTAINER_IMAGE_HELLO
  - [ ] KONG_DB_PASSWORD
- [ ] ECR repository created
- [ ] Container image pushed to ECR
- [ ] GitHub Actions workflow file exists
- [ ] Test workflow triggered successfully
- [ ] Terraform plan runs successfully
- [ ] Branch protection enabled (optional)
- [ ] Slack notifications configured (optional)

## Quick Reference

### Create All Secrets at Once

```bash
# Set your values
export AWS_ACCOUNT_ID="123456789012"
export AWS_REGION="us-east-1"
export CONTAINER_IMAGE="123456789012.dkr.ecr.us-east-1.amazonaws.com/sbxservice-hello-service:latest"
export KONG_PASSWORD="YourSecurePassword123!"

# Create secrets
gh secret set AWS_ACCOUNT_ID --body "$AWS_ACCOUNT_ID"
gh secret set AWS_REGION --body "$AWS_REGION"
gh secret set CONTAINER_IMAGE_HELLO --body "$CONTAINER_IMAGE"
gh secret set KONG_DB_PASSWORD --body "$KONG_PASSWORD"

# Verify
gh secret list
```

### Update a Secret

```bash
gh secret set SECRET_NAME --body "new-value"
```

### Delete a Secret

```bash
gh secret delete SECRET_NAME
```

## Support

For issues with:
- **IAM roles**: Check AWS IAM console
- **GitHub Actions**: Check Actions tab in repository
- **Terraform**: Check workflow logs
- **Secrets**: Use `gh secret list` to verify

## Next Steps

After successful setup:
1. Test the workflow with a small change
2. Monitor the deployment
3. Set up monitoring and alerts
4. Configure auto-apply for production
5. Document your deployment process

