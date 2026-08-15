# ============================================================
# Terraform Backend Configuration
# ============================================================

# Local backend (dùng cho demo - state lưu trên disk)
# State file: terraform/environments/dev/terraform.tfstate

terraform {
  # Dùng local backend cho demo
  # State file được lưu tại: terraform/environments/dev/terraform.tfstate
}

# ============================================================
# S3 Backend (uncomment khi chuyển sang production/teamwork)
# ============================================================
# terraform {
#   backend "s3" {
#     bucket         = "your-terraform-state-bucket"
#     key            = "terraform/dev/terraform.tfstate"
#     region         = "ap-southeast-1"
#     dynamodb_table = "terraform-state-lock"
#     encrypt        = true
#   }
# }
#
# Lưu ý: Cần tạo S3 bucket và DynamoDB table trước khi uncomment:
#   - S3 bucket với versioning enabled
#   - DynamoDB table với partition key "LockID" (String)
