output "cluster_name" {
  description = "Tên của EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "CA data để config kubectl"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL (dùng cho IRSA sau này)"
  value       = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "ARN của IAM OIDC Provider"
  value       = aws_iam_openid_connect_provider.eks_oidc[0].arn
}

output "cluster_security_group_id" {
  description = "Security group của EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "node_group_role_arn" {
  description = "ARN của IAM role cho managed node group (dùng cho aws-auth)"
  value       = module.eks.eks_managed_node_groups["default"].iam_role_arn
}
