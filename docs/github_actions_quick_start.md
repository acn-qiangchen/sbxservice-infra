# GitHub Actions Quick Start

## TL;DR - What You Need to Do

Your GitHub Actions workflow uses **workflow_dispatch** (manual trigger), so you don't need to set up GitHub Secrets. Instead, you provide values when manually triggering the workflow.

## How to Run the Workflow

### Step 1: Set Up IAM Role (One-time Setup)

```bash
cd scripts
./setup-github-actions-role.sh -a YOUR_AWS_ACCOUNT_ID
```

This creates the `github-actions-role` that GitHub Actions will use.

### Step 2: Push Container Image to ECR (Before Each Deploy)

```bash
# Build your hello-service image
docker buildx build --platform linux/amd64 -t hello-service:latest .

# Tag for ECR
docker tag hello-service:latest \
  YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/sbxservice-hello-service:latest

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

# Push
docker push YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/sbxservice-hello-service:latest
```

### Step 3: Trigger Workflow Manually

1. Go to **GitHub Repository → Actions**
2. Click **Terraform Operations** workflow
3. Click **Run workflow** button
4. Fill in the parameters:
   - **environment**: `dev` (or `test`, `prod`)
   - **tag**: `latest` (or specific version)
   - **aws_account_id**: Your AWS account ID (e.g., `123456789012`)
5. Click **Run workflow**

## What the Workflow Does

1. ✅ Checks out your code
2. ✅ Authenticates with AWS using OIDC
3. ✅ Creates S3 bucket for Terraform state (if needed)
4. ✅ Creates DynamoDB table for state locking (if needed)
5. ✅ Runs `terraform init`
6. ✅ Runs `terraform validate`
7. ✅ Constructs container image URL
8. ✅ Creates `terraform.tfvars` automatically
9. ✅ Runs `terraform plan`
10. ✅ Runs `terraform apply -auto-approve`

## What Gets Created Automatically

### S3 Bucket (for Terraform State)
- **Name**: `sbxservice-terraform-state-{YOUR_ACCOUNT_ID}`
- **Versioning**: Enabled
- **Encryption**: AES256

### DynamoDB Table (for State Locking)
- **Name**: `sbxservice-terraform-locks-{YOUR_ACCOUNT_ID}`
- **Billing**: Pay-per-request

### Terraform Variables File
The workflow automatically creates `terraform.tfvars` with:
```hcl
environment = "dev"
aws_profile = ""
aws_account_id = "123456789012"
container_image_hello = "123456789012.dkr.ecr.us-east-1.amazonaws.com/sbxservice-hello-service:latest"
```

Note: Kong database password uses the default value from `variables.tf`

## What You DON'T Need to Set Up

❌ **No GitHub Secrets required** - Everything is provided via workflow inputs
❌ **No manual tfvars file** - Created automatically
❌ **No manual S3 bucket creation** - Created automatically
❌ **No manual DynamoDB table** - Created automatically
❌ **No password configuration** - Uses default hardcoded password

## Kong Database Password

The Kong database uses a default hardcoded password: `KongPassword123!`

This is set in `terraform/variables.tf` as the default value.

### To Change the Password

If you want to use a different password, you can:

**Option 1: Update the default in variables.tf**
```hcl
variable "kong_db_password" {
  default = "YourCustomPassword"
}
```

**Option 2: Override in terraform.tfvars**
```hcl
kong_db_password = "YourCustomPassword"
```

**Option 3: Pass as environment variable**
```bash
export TF_VAR_kong_db_password="YourCustomPassword"
```

## Monitoring the Workflow

### View Progress
1. Go to **Actions** tab
2. Click on the running workflow
3. Watch each step execute

### View Summary
After completion, check the **Summary** tab for:
- Terraform plan changes
- Container image used
- Domain configuration
- Terraform outputs

### View Outputs
Terraform outputs are shown in the summary:
- ALB URL
- Kong Admin API endpoint
- Database endpoints
- etc.

## Troubleshooting

### Error: "No valid credential sources"
**Solution**: Run the IAM role setup script again:
```bash
./scripts/setup-github-actions-role.sh -a YOUR_ACCOUNT_ID
```

### Error: "Image not found"
**Solution**: Push your container image to ECR first:
```bash
# Check if ECR repo exists
aws ecr describe-repositories --repository-names sbxservice-hello-service

# If not, create it
aws ecr create-repository --repository-name sbxservice-hello-service

# Push image
docker push YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/sbxservice-hello-service:latest
```

### Error: "Access Denied"
**Solution**: Check IAM role has correct permissions:
```bash
aws iam get-role --role-name github-actions-role
aws iam list-attached-role-policies --role-name github-actions-role
```

## Complete Example

Here's a complete workflow run:

```bash
# 1. Setup IAM role (one-time)
./scripts/setup-github-actions-role.sh -a 123456789012

# 2. Build and push container
docker buildx build --platform linux/amd64 -t hello-service:latest .
docker tag hello-service:latest 123456789012.dkr.ecr.us-east-1.amazonaws.com/sbxservice-hello-service:latest
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/sbxservice-hello-service:latest

# 3. Trigger workflow via GitHub UI
# - environment: dev
# - tag: latest
# - aws_account_id: 123456789012

# 4. Wait for completion and check outputs
```

## Next Steps

After successful deployment:
1. Get ALB URL from workflow outputs
2. Test the application:
   ```bash
   curl https://alb.YOUR_ACCOUNT_ID.realhandsonlabs.net/hello
   ```
3. Configure Kong Gateway:
   ```bash
   export KONG_ADMIN_URL=$(terraform output -raw kong_admin_api_endpoint)
   ./scripts/kong-setup.sh setup
   ```

## Workflow File Location

`.github/workflows/terraform.yml`

To modify the workflow, edit this file and commit the changes.

