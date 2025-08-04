#!/bin/bash
set -e

# Script to connect Gloo Gateway LoadBalancer service to pre-created NLB target group
# This script registers the Gloo Gateway pods with the Terraform-managed NLB target group

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration - these should match your Terraform outputs
CLUSTER_NAME="${CLUSTER_NAME:-sbxservice-dev-gloo-cluster}"
REGION="${AWS_REGION:-us-east-1}"
NAMESPACE="gloo-system"
SERVICE_NAME="gateway-proxy"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install kubectl."
        exit 1
    fi
    
    if ! command -v aws &> /dev/null; then
        print_error "aws CLI is not installed. Please install AWS CLI."
        exit 1
    fi
    
    # Check AWS_PROFILE
    if [ -z "$AWS_PROFILE" ]; then
        print_warning "AWS_PROFILE environment variable is not set. Please set it to continue."
        exit 1
    fi
    
    print_status "Prerequisites check completed."
}

# Get the target group ARN from Terraform output
get_target_group_arn() {
    print_status "Getting Gloo NLB target group ARN from Terraform..."
    
    TARGET_GROUP_ARN=$(terraform output -raw gloo_nlb_target_group_arn 2>/dev/null || echo "")
    
    if [ -z "$TARGET_GROUP_ARN" ] || [ "$TARGET_GROUP_ARN" = "null" ]; then
        print_error "Could not get Gloo NLB target group ARN from Terraform output."
        print_error "Make sure you have run 'terraform apply' and that gloo_enabled = true."
        exit 1
    fi
    
    print_status "Target Group ARN: $TARGET_GROUP_ARN"
}

# Get Gloo Gateway pod IPs
get_gloo_pod_ips() {
    print_status "Getting Gloo Gateway pod IPs..."
    
    # Configure kubectl
    aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME
    
    # Get pod IPs
    POD_IPS=$(kubectl get pods -n $NAMESPACE -l gloo=gateway-proxy -o jsonpath='{.items[*].status.podIP}' 2>/dev/null || echo "")
    
    if [ -z "$POD_IPS" ]; then
        print_error "Could not find Gloo Gateway pods or pod IPs."
        print_error "Make sure Gloo Gateway is installed and pods are running."
        exit 1
    fi
    
    print_status "Found Gloo Gateway pod IPs: $POD_IPS"
}

# Register pods with target group
register_pods() {
    print_status "Registering Gloo Gateway pods with NLB target group..."
    
    for POD_IP in $POD_IPS; do
        print_status "Registering pod IP: $POD_IP"
        
        aws elbv2 register-targets \
            --target-group-arn "$TARGET_GROUP_ARN" \
            --targets Id="$POD_IP",Port=8080
        
        if [ $? -eq 0 ]; then
            print_status "Successfully registered $POD_IP"
        else
            print_error "Failed to register $POD_IP"
        fi
    done
}

# Check target health
check_target_health() {
    print_status "Checking target health..."
    
    sleep 10  # Wait a bit for registration to take effect
    
    aws elbv2 describe-target-health --target-group-arn "$TARGET_GROUP_ARN"
}

# Main function
main() {
    print_status "Connecting Gloo Gateway to pre-created NLB target group..."
    
    check_prerequisites
    get_target_group_arn
    get_gloo_pod_ips
    register_pods
    check_target_health
    
    print_status "Gloo Gateway connection to NLB completed!"
    echo ""
    print_status "You can now test the gateway through the ALB with header routing:"
    echo "curl -H 'X-Gateway: gloo' https://your-alb-domain/"
}

# Run main function
main "$@"