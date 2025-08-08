# Gloo Gateway Quickstart Commands - AWS CloudShell

This guide contains all the commands for following the [Gloo Gateway quickstart](https://docs.solo.io/gateway/main/quickstart/) step-by-step using AWS CloudShell.

## 🚀 Step-by-Step Commands

### Step 1: Open AWS CloudShell and Set Up Environment

```bash
# Open AWS CloudShell from the AWS Console
# Set your AWS profile if needed
export AWS_PROFILE=your-profile-name  # Optional if using default

# Set your preferred region
export AWS_REGION=us-east-1
```

### Step 2: Create a Simple EKS Cluster

```bash
# Install eksctl if not available
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Create a simple EKS cluster for testing
eksctl create cluster \
  --name gloo-quickstart \
  --region $AWS_REGION \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 1 \
  --nodes-min 1 \
  --nodes-max 1 \
  --managed
```

**Note**: This will take about 15-20 minutes to create.

### Step 3: Install Prerequisites

```bash
# Install kubectl (usually pre-installed in CloudShell)
kubectl version --client

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install glooctl
curl -sL https://run.solo.io/gloo/install | sh
export PATH=$HOME/.gloo/bin:$PATH

# Verify installations
kubectl version --client
helm version
glooctl version
```

### Step 4: Configure kubectl for EKS

```bash
# Update kubeconfig to connect to your EKS cluster
aws eks update-kubeconfig --region $AWS_REGION --name gloo-quickstart

# Verify connection
kubectl get nodes
```

### Step 5: Install Gateway API CRDs

```bash
# Install the Kubernetes Gateway API CRDs (required for Gloo Gateway)
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml

# Verify Gateway API CRDs are installed
kubectl get crd | grep gateway
```

**Expected output:**
```
gatewayclasses.gateway.networking.k8s.io
gateways.gateway.networking.k8s.io  
httproutes.gateway.networking.k8s.io
referencegrants.gateway.networking.k8s.io
```

### Step 6: Install Gloo Gateway (Open Source)

```bash
# Add the Gloo Gateway Helm repository
helm repo add gloo https://storage.googleapis.com/solo-public-helm
helm repo update

# Install Gloo Gateway with Kubernetes Gateway API Support
helm install -n gloo-system gloo gloo/gloo --create-namespace --version 1.20.0-beta10 -f -<<EOF
discovery:
  enabled: false
gatewayProxies:
  gatewayProxy:
    disabled: true
gloo:
  disableLeaderElection: true
kubeGateway:
  enabled: true
EOF
```

**Important**: This configuration enables Kubernetes Gateway API support with:
- `kubeGateway.enabled: true` - Enables Gateway API controller
- `discovery.enabled: false` - Disables Gloo's discovery for simpler setup
- `gatewayProxies.gatewayProxy.disabled: true` - Uses Gateway API instead of Gloo's proxy
- `gloo.disableLeaderElection: true` - For single-replica deployment

### Step 7: Verify Gloo Gateway Installation

```bash
# Wait for Gloo Gateway to be ready
kubectl wait --for=condition=available --timeout=300s deployment/gloo -n gloo-system
kubectl wait --for=condition=available --timeout=300s deployment/discovery -n gloo-system
kubectl wait --for=condition=available --timeout=300s deployment/gateway-proxy -n gloo-system

# Check the pods
kubectl get pods -n gloo-system

# Verify the GatewayClass is created
kubectl get gatewayclass gloo-gateway
```

**Expected output:**
```
NAME           CONTROLLER             ACCEPTED   AGE
gloo-gateway   solo.io/gloo-gateway   True       2m
```

### Step 8: Set Up the API Gateway

```bash
# Create the Gateway resource
kubectl apply -n gloo-system -f- <<EOF
kind: Gateway
apiVersion: gateway.networking.k8s.io/v1
metadata:
  name: http
spec:
  gatewayClassName: gloo-gateway
  listeners:
  - protocol: HTTP
    port: 8080
    name: http
    allowedRoutes:
      namespaces:
        from: All
EOF

# Verify the gateway is created
kubectl get gateway http -n gloo-system
```

### Step 9: Deploy the Sample App

```bash
# Create the httpbin namespace
kubectl create ns httpbin

# Deploy the httpbin app
kubectl -n httpbin apply -f https://raw.githubusercontent.com/solo-io/gloo-mesh-use-cases/main/policy-demo/httpbin.yaml

# Verify the app is running
kubectl -n httpbin get pods
```

**Wait for the pod to be in `Running` status.**

### Step 10: Expose the App on the Gateway

```bash
# Create the HTTPRoute
kubectl apply -f- <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
  labels:
    example: httpbin-route
spec:
  parentRefs:
    - name: http
      namespace: gloo-system
  hostnames:
    - "www.example.com"
  rules:
    - backendRefs:
        - name: httpbin
          port: 8000
EOF

# Verify the HTTPRoute
kubectl get httproute -n httpbin
```

### Step 11: Test the Setup

```bash
# Get the LoadBalancer address
export INGRESS_GW_ADDRESS=$(kubectl get svc -n gloo-system gateway-proxy -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Gateway address: $INGRESS_GW_ADDRESS"

# Wait for LoadBalancer to be ready (may take a few minutes)
echo "Waiting for LoadBalancer to be ready..."
while [ -z "$INGRESS_GW_ADDRESS" ]; do
  sleep 10
  export INGRESS_GW_ADDRESS=$(kubectl get svc -n gloo-system gateway-proxy -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
done

# Test the gateway
curl -i http://$INGRESS_GW_ADDRESS:8080/headers -H "host: www.example.com"
```

**Expected output should include:**
```
HTTP/1.1 200 OK
server: envoy
date: Wed, 17 Jan 2024 17:32:21 GMT
content-type: application/json
content-length: 211
access-control-allow-origin: *
access-control-allow-credentials: true
x-envoy-upstream-service-time: 2
```

### Step 12: Alternative Local Testing (if LoadBalancer takes time)

```bash
# Port-forward for local testing
kubectl port-forward -n gloo-system deployment/gateway-proxy 8080:8080 &

# Test locally
curl -i localhost:8080/headers -H "host: www.example.com"

# Stop port-forward when done
kill %1
```

### Step 13: Explore Gloo Gateway Features

```bash
# Check gateway status
kubectl describe gateway http -n gloo-system

# View HTTPRoute details
kubectl describe httproute httpbin -n httpbin

# Check Gloo Gateway logs
kubectl logs -l gloo=gateway-proxy -n gloo-system

# List all Gloo resources
kubectl get all -n gloo-system

# Check gateway-proxy service details
kubectl get svc gateway-proxy -n gloo-system -o yaml

# View Gloo Gateway configuration
kubectl get upstream -n gloo-system
kubectl get virtualservice -n gloo-system
```

### Step 14: Additional Testing Commands

```bash
# Test different endpoints
curl -i http://$INGRESS_GW_ADDRESS:8080/get -H "host: www.example.com"
curl -i http://$INGRESS_GW_ADDRESS:8080/status/200 -H "host: www.example.com"
curl -i http://$INGRESS_GW_ADDRESS:8080/json -H "host: www.example.com"

# Test with different HTTP methods
curl -i -X POST http://$INGRESS_GW_ADDRESS:8080/post -H "host: www.example.com" -d '{"test": "data"}'

# Check response times
time curl -s http://$INGRESS_GW_ADDRESS:8080/delay/2 -H "host: www.example.com"
```

### Step 15: View Gloo Gateway Metrics and Status

```bash
# Check Gloo Gateway version
glooctl version

# Get cluster info
kubectl cluster-info

# Check node resources
kubectl top nodes

# Check pod resources in gloo-system
kubectl top pods -n gloo-system

# Get detailed pod information
kubectl get pods -n gloo-system -o wide
```

### Step 16: Cleanup (When Done)

```bash
# Delete the HTTPRoute and sample app
kubectl delete httproute httpbin -n httpbin
kubectl delete ns httpbin

# Delete the Gateway
kubectl delete gateway http -n gloo-system

# Uninstall Gloo Gateway
helm uninstall gloo-gateway -n gloo-system

# Delete the namespace
kubectl delete ns gloo-system

# Delete the EKS cluster (this will take 10-15 minutes)
eksctl delete cluster --name gloo-quickstart --region $AWS_REGION
```

## 🔍 Troubleshooting Commands

### Common Issues

#### Gateway API CRDs Not Found
If you get error: `the server doesn't have a resource type "gatewayclass"`:

```bash
# Install Gateway API CRDs manually
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml

# Verify installation
kubectl get crd | grep gateway
kubectl api-resources | grep gateway
```

#### GatewayClass Not Created After Installation
If you get error: `gatewayclasses.gateway.networking.k8s.io "gloo-gateway" not found`:

```bash
# Check what GatewayClasses exist (if any)
kubectl get gatewayclass

# Check Gloo Gateway pods status
kubectl get pods -n gloo-system

# Check if gloo controller is running and ready
kubectl logs deployment/gloo -n gloo-system | tail -20

# Check Gloo Gateway version and settings
helm list -n gloo-system
helm get values gloo-gateway -n gloo-system

# Try creating GatewayClass manually
kubectl apply -f- <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: gloo-gateway
spec:
  controllerName: solo.io/gloo-gateway
EOF
```

#### General Troubleshooting

```bash
# If pods are not starting
kubectl describe pods -n gloo-system

# Check events
kubectl get events -n gloo-system --sort-by='.lastTimestamp'

# Check LoadBalancer service status
kubectl describe svc gateway-proxy -n gloo-system

# Check if Gateway is programmed
kubectl get gateway http -n gloo-system -o yaml

# Check HTTPRoute status
kubectl get httproute httpbin -n httpbin -o yaml

# View Gloo Gateway controller logs
kubectl logs deployment/gloo -n gloo-system

# View discovery service logs
kubectl logs deployment/discovery -n gloo-system

# View gateway-proxy logs
kubectl logs deployment/gateway-proxy -n gloo-system
```

## 📝 Key Files Created

During this quickstart, the following Kubernetes resources are created:

- **GatewayClass**: `gloo-gateway` (created by Helm install)
- **Gateway**: `http` in `gloo-system` namespace
- **HTTPRoute**: `httpbin` in `httpbin` namespace
- **Service**: `httpbin` in `httpbin` namespace
- **Deployment**: `httpbin` in `httpbin` namespace

## 🎯 Learning Outcomes

After completing this quickstart, you will understand:

1. How to install Gloo Gateway on EKS
2. How to configure Gateway and HTTPRoute resources
3. How to expose applications through Gloo Gateway
4. How to test and troubleshoot gateway configurations
5. How Kubernetes Gateway API works with Gloo Gateway

## 📚 References

- [Gloo Gateway Quickstart Documentation](https://docs.solo.io/gateway/main/quickstart/)
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
- [Gloo Gateway Documentation](https://docs.solo.io/gateway/main/)
- [Solo.io Gloo Gateway](https://www.solo.io/products/gloo-gateway/)

---

**Note**: This quickstart is for learning purposes. For production deployments, consider additional security, monitoring, and scaling configurations as described in the [production setup guide](../gloo-gateway-setup.md).