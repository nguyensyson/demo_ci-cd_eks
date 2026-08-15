variable "project_name" {
  description = "Tên project dùng làm prefix cho resource"
  type        = string
}

variable "environment" {
  description = "Môi trường deploy (dev, staging, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block cho VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Danh sách AZ dùng trong VPC"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "cluster_name" {
  description = "Tên EKS cluster (để tag subnet cho LB Controller)"
  type        = string
  default     = ""
}
