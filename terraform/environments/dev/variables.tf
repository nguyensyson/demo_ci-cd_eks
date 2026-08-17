variable "project_name" {
  description = "Tên project"
  type        = string
  default     = "demo-app"
}

variable "environment" {
  description = "Môi trường deploy"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "vpc_cidr" {
  description = "CIDR cho VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Danh sách AZ"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "cluster_version" {
  description = "Kubernetes version cho EKS"
  type        = string
  default     = "1.31"
}
