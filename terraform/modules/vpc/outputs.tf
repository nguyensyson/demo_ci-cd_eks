output "vpc_id" {
  description = "ID của VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block của VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnet_ids" {
  description = "Danh sách ID của private subnets (dùng cho EKS nodes)"
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "Danh sách ID của public subnets (dùng cho ALB/NAT)"
  value       = module.vpc.public_subnets
}

output "availability_zones" {
  description = "Danh sách AZ trong VPC"
  value       = var.availability_zones
}
