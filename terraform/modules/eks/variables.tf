variable "project_name" {
  description = "Tên project dùng làm prefix cho cluster"
  type        = string
}

variable "environment" {
  description = "Môi trường deploy"
  type        = string
}

variable "vpc_id" {
  description = "ID của VPC đã tạo từ module vpc"
  type        = string
}

variable "private_subnet_ids" {
  description = "Danh sách ID của private subnets để deploy EKS nodes"
  type        = list(string)
}

variable "cluster_version" {
  description = "Phiên bản Kubernetes cho EKS cluster"
  type        = string
  default     = "1.30"
}
