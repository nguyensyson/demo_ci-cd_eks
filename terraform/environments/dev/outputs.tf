# ============================================================
# VPC Outputs
# ============================================================
output "vpc_id" {
  description = "ID của VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block của VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnet_ids" {
  description = "Private subnets cho EKS"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnets cho ALB"
  value       = module.vpc.public_subnet_ids
}

# ============================================================
# EKS Outputs
# ============================================================
output "cluster_name" {
  description = "Tên EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "CA data cho kubectl config"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "oidc_provider_arn" {
  description = "ARN của IAM OIDC Provider (dùng cho IRSA)"
  value       = module.eks.oidc_provider_arn
}

# ============================================================
# ECR Outputs
# ============================================================
output "repository_urls" {
  description = "ECR repository URLs cho Jenkins push image"
  value       = module.ecr.repository_urls
}

# ============================================================
# kubectl config command
# ============================================================
output "eks_config_command" {
  description = "Lệnh cấu hình kubectl để kết nối EKS"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}
