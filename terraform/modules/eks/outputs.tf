# EKS Cluster outputs
output "cluster_id" {
  description = "ID of the EKS cluster"
  value       = var.gloo_enabled ? aws_eks_cluster.gloo_cluster[0].id : null
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = var.gloo_enabled ? aws_eks_cluster.gloo_cluster[0].arn : null
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = var.gloo_enabled ? aws_eks_cluster.gloo_cluster[0].name : null
}

output "cluster_endpoint" {
  description = "Endpoint for the EKS cluster"
  value       = var.gloo_enabled ? aws_eks_cluster.gloo_cluster[0].endpoint : null
}

output "cluster_ca_certificate" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = var.gloo_enabled ? aws_eks_cluster.gloo_cluster[0].certificate_authority[0].data : null
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = var.gloo_enabled ? aws_security_group.eks_cluster[0].id : null
}

output "fargate_pods_security_group_id" {
  description = "Security group ID for Fargate pods"
  value       = var.gloo_enabled ? aws_security_group.eks_fargate_pods[0].id : null
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = var.gloo_enabled ? aws_eks_cluster.gloo_cluster[0].identity[0].oidc[0].issuer : null
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for EKS"
  value       = var.gloo_enabled ? aws_iam_openid_connect_provider.eks_oidc[0].arn : null
}

# Role ARNs
output "cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = var.gloo_enabled ? aws_iam_role.eks_cluster_role[0].arn : null
}

output "fargate_role_arn" {
  description = "ARN of the EKS Fargate IAM role"
  value       = var.gloo_enabled ? aws_iam_role.eks_fargate_role[0].arn : null
}