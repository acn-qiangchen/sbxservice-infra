# ============================================================================
# EKS Fargate Module for Gloo Gateway Control Plane
# 
# This module creates a minimal EKS cluster using Fargate for serverless 
# container execution. The cluster hosts Gloo Gateway control plane.
# ============================================================================

# EKS Cluster
resource "aws_eks_cluster" "gloo_cluster" {
  count    = var.gloo_enabled ? 1 : 0
  name     = "${var.project_name}-${var.environment}-gloo-cluster"
  role_arn = aws_iam_role.eks_cluster_role[0].arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.private_subnets
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]
    security_group_ids      = [aws_security_group.eks_cluster[0].id]
  }

  # Enable logging
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_cloudwatch_log_group.eks_cluster,
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-gloo-cluster"
  }
}

# EKS Fargate Profile for Gloo Gateway
resource "aws_eks_fargate_profile" "gloo_fargate" {
  count                  = var.gloo_enabled ? 1 : 0
  cluster_name           = aws_eks_cluster.gloo_cluster[0].name
  fargate_profile_name   = "${var.project_name}-${var.environment}-gloo-fargate"
  pod_execution_role_arn = aws_iam_role.eks_fargate_role[0].arn
  subnet_ids             = var.private_subnets

  selector {
    namespace = "gloo-system"
  }

  selector {
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name" = "coredns"
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-gloo-fargate"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_fargate_policy,
  ]
}

# EKS Fargate Profile for Default namespace (for applications)
resource "aws_eks_fargate_profile" "default_fargate" {
  count                  = var.gloo_enabled ? 1 : 0
  cluster_name           = aws_eks_cluster.gloo_cluster[0].name
  fargate_profile_name   = "${var.project_name}-${var.environment}-default-fargate"
  pod_execution_role_arn = aws_iam_role.eks_fargate_role[0].arn
  subnet_ids             = var.private_subnets

  selector {
    namespace = "default"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-default-fargate"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_fargate_policy,
  ]
}

# ============================================================================
# IAM Roles and Policies
# ============================================================================

# EKS Cluster IAM Role
resource "aws_iam_role" "eks_cluster_role" {
  count = var.gloo_enabled ? 1 : 0
  name  = "${var.project_name}-${var.environment}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-eks-cluster-role"
  }
}

# Attach required policies to EKS cluster role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  count      = var.gloo_enabled ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role[0].name
}

# EKS Fargate Pod Execution IAM Role
resource "aws_iam_role" "eks_fargate_role" {
  count = var.gloo_enabled ? 1 : 0
  name  = "${var.project_name}-${var.environment}-eks-fargate-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks-fargate-pods.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-eks-fargate-role"
  }
}

# Attach required policies to Fargate role
resource "aws_iam_role_policy_attachment" "eks_fargate_policy" {
  count      = var.gloo_enabled ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.eks_fargate_role[0].name
}

# ============================================================================
# Security Groups
# ============================================================================

# EKS Cluster Security Group
resource "aws_security_group" "eks_cluster" {
  count       = var.gloo_enabled ? 1 : 0
  name        = "${var.project_name}-${var.environment}-eks-cluster-sg"
  description = "Security group for EKS cluster control plane"
  vpc_id      = var.vpc_id

  # Allow HTTPS communication with EKS API server
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS from VPC"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-eks-cluster-sg"
  }
}

# EKS Node Security Group (for Fargate pods)
resource "aws_security_group" "eks_fargate_pods" {
  count       = var.gloo_enabled ? 1 : 0
  name        = "${var.project_name}-${var.environment}-eks-fargate-pods-sg"
  description = "Security group for EKS Fargate pods"
  vpc_id      = var.vpc_id

  # Allow communication with cluster security group
  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster[0].id]
    description     = "Communication with EKS cluster"
  }

  # Allow communication between pods
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
    description = "Communication between pods"
  }

  # Allow HTTP traffic from NLB (for Gloo Gateway)
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTP traffic from NLB"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-eks-fargate-pods-sg"
  }
}

# ============================================================================
# CloudWatch Log Groups
# ============================================================================

# EKS Cluster CloudWatch Log Group
resource "aws_cloudwatch_log_group" "eks_cluster" {
  count             = var.gloo_enabled ? 1 : 0
  name              = "/aws/eks/${var.project_name}-${var.environment}-gloo-cluster/cluster"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-${var.environment}-eks-cluster-logs"
  }
}

# ============================================================================
# EKS Add-ons
# ============================================================================

# CoreDNS Add-on for DNS resolution
resource "aws_eks_addon" "coredns" {
  count        = var.gloo_enabled ? 1 : 0
  cluster_name = aws_eks_cluster.gloo_cluster[0].name
  addon_name   = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_fargate_profile.gloo_fargate,
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-coredns"
  }
}

# VPC CNI Add-on for pod networking
resource "aws_eks_addon" "vpc_cni" {
  count        = var.gloo_enabled ? 1 : 0
  cluster_name = aws_eks_cluster.gloo_cluster[0].name
  addon_name   = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc-cni"
  }
}

# kube-proxy Add-on for service networking
resource "aws_eks_addon" "kube_proxy" {
  count        = var.gloo_enabled ? 1 : 0
  cluster_name = aws_eks_cluster.gloo_cluster[0].name
  addon_name   = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Name = "${var.project_name}-${var.environment}-kube-proxy"
  }
}

# ============================================================================
# OIDC Provider for EKS (required for service accounts with IAM roles)
# ============================================================================

# Get OIDC issuer URL
data "tls_certificate" "eks_oidc" {
  count = var.gloo_enabled ? 1 : 0
  url   = aws_eks_cluster.gloo_cluster[0].identity[0].oidc[0].issuer
}

# Create OIDC provider
resource "aws_iam_openid_connect_provider" "eks_oidc" {
  count           = var.gloo_enabled ? 1 : 0
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc[0].certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.gloo_cluster[0].identity[0].oidc[0].issuer

  tags = {
    Name = "${var.project_name}-${var.environment}-eks-oidc"
  }
}