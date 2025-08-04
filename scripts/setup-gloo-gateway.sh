#!/bin/bash
set -e

# Gloo Gateway Setup Script for EKS Fargate
# This script installs Gloo Gateway Open Source edition on EKS and configures it

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-sbxservice-dev-gloo-cluster}"
REGION="${AWS_REGION:-us-east-1}"
NAMESPACE="gloo-system"
RELEASE_NAME="gloo-gateway"

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

# Check if required tools are installed
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install kubectl."
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        print_error "helm is not installed. Please install helm."
        exit 1
    fi
    
    if ! command -v aws &> /dev/null; then
        print_error "aws CLI is not installed. Please install AWS CLI."
        exit 1
    fi

    # Check AWS_PROFILE
    if [ -z "$AWS_PROFILE" ]; then
        print_warning "AWS_PROFILE environment variable is not set. Please set it to continue."
        print_warning "Example: export AWS_PROFILE=your-profile-name"
        exit 1
    fi
    
    print_status "Prerequisites check completed."
}

# Configure kubectl to use the EKS cluster
configure_kubectl() {
    print_status "Configuring kubectl for EKS cluster: $CLUSTER_NAME"
    aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME
    
    # Test connection
    if ! kubectl get nodes &> /dev/null; then
        print_error "Failed to connect to EKS cluster. Please check your AWS credentials and cluster status."
        exit 1
    fi
    
    print_status "Successfully connected to EKS cluster."
}

# Add Gloo Gateway Helm repository
add_helm_repo() {
    print_status "Adding Gloo Gateway Helm repository..."
    helm repo add gloo https://storage.googleapis.com/solo-public-helm
    helm repo update
    print_status "Helm repository added and updated."
}

# Install Gloo Gateway
install_gloo_gateway() {
    print_status "Installing Gloo Gateway (Open Source Edition)..."
    
    # Create namespace if it doesn't exist
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Install Gloo Gateway using Helm
    helm upgrade --install $RELEASE_NAME gloo/gloo \
        --namespace $NAMESPACE \
        --set discovery.fdsMode=WHITELIST \
        --set gateway.validation.enabled=false \
        --set gloo.disableLeaderElection=true \
        --set gateway.proxyServiceType=LoadBalancer \
        --set gateway.proxyServiceAnnotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb" \
        --set gateway.proxyServiceAnnotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"="internal" \
        --set gateway.proxyServiceAnnotations."service\.beta\.kubernetes\.io/aws-load-balancer-cross-zone-load-balancing-enabled"="true" \
        --set gateway.proxyServiceAnnotations."service\.beta\.kubernetes\.io/aws-load-balancer-target-group-attributes"="deregistration_delay.timeout_seconds=30" \
        --wait --timeout=10m
    
    print_status "Gloo Gateway installation completed."
}

# Wait for Gloo Gateway to be ready
wait_for_gloo() {
    print_status "Waiting for Gloo Gateway components to be ready..."
    
    # Wait for deployments to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/gloo -n $NAMESPACE
    kubectl wait --for=condition=available --timeout=300s deployment/discovery -n $NAMESPACE
    kubectl wait --for=condition=available --timeout=300s deployment/gateway-proxy -n $NAMESPACE
    
    print_status "Gloo Gateway components are ready."
}

# Get the LoadBalancer service information
get_service_info() {
    print_status "Getting Gloo Gateway service information..."
    
    echo ""
    echo "=== Gloo Gateway Service Status ==="
    kubectl get svc gateway-proxy -n $NAMESPACE
    
    echo ""
    echo "=== Gloo Gateway Pods ==="
    kubectl get pods -n $NAMESPACE
    
    # Try to get the LoadBalancer hostname
    LB_HOSTNAME=$(kubectl get svc gateway-proxy -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    
    if [ ! -z "$LB_HOSTNAME" ]; then
        print_status "LoadBalancer hostname: $LB_HOSTNAME"
        echo ""
        echo "You can test the gateway with:"
        echo "curl -H 'X-Gateway: gloo' http://$LB_HOSTNAME:8080/"
    else
        print_warning "LoadBalancer hostname not yet available. It may take a few minutes to provision."
    fi
}

# Install required Custom Resource Definitions if they don't exist
install_crds() {
    print_status "Checking for required CRDs..."
    
    # Check if Gloo CRDs exist, if not they will be installed with Helm chart
    print_status "CRDs will be installed automatically with Helm chart."
}

# Main installation flow
main() {
    print_status "Starting Gloo Gateway installation on EKS Fargate..."
    echo "Cluster: $CLUSTER_NAME"
    echo "Region: $REGION"
    echo "Namespace: $NAMESPACE"
    echo ""
    
    check_prerequisites
    configure_kubectl
    add_helm_repo
    install_crds
    install_gloo_gateway
    wait_for_gloo
    get_service_info
    
    print_status "Gloo Gateway installation completed successfully!"
    echo ""
    print_status "Next steps:"
    echo "1. Apply Gloo Gateway configuration: kubectl apply -f kubernetes/gloo-gateway-config.yaml"
    echo "2. Test the gateway with header-based routing: curl -H 'X-Gateway: gloo' https://your-alb-domain/"
}

# Run main function
main "$@"