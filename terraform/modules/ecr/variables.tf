variable "project_name" {
  description = "Tên project dùng làm prefix cho repository"
  type        = string
}

variable "environment" {
  description = "Môi trường deploy"
  type        = string
}

variable "repository_names" {
  description = "Danh sách tên ECR repositories cần tạo"
  type        = list(string)
  default     = ["backend", "frontend"]
}

variable "scan_on_push" {
  description = "Bật image scanning trên mỗi push"
  type        = bool
  default     = true
}
