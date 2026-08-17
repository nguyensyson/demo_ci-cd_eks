# ============================================================
# AWS Provider
# ============================================================
provider "aws" {
  region = var.aws_region
}

# ============================================================
# Local Values
# ============================================================
locals {
  cluster_name = "${var.project_name}-${var.environment}-eks"
}

# ============================================================
# Module: VPC
# ============================================================
module "vpc" {
  source = "../../modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  cluster_name       = local.cluster_name
}

# ============================================================
# Module: EKS
# ============================================================
module "eks" {
  source = "../../modules/eks"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  cluster_version    = var.cluster_version
}

# ============================================================
# Module: ECR
# ============================================================
module "ecr" {
  source = "../../modules/ecr"

  project_name     = var.project_name
  environment      = var.environment
  repository_names = ["backend", "frontend"]
  scan_on_push     = true
}

# ============================================================
# IAM: kubectl access via EKS Access Entry
# ============================================================
# Lấy ARN của IAM user/role hiện tại đang chạy terraform
data "aws_caller_identity" "current" {}

# Cấp quyền cluster access cho IAM identity đang chạy terraform
# Dùng aws_eks_access_entry (thay thế deprecated aws-auth configmap)
resource "aws_eks_access_entry" "terraform_user" {
  cluster_name  = module.eks.cluster_name
  principal_arn = data.aws_caller_identity.current.arn

  depends_on = [module.eks]
}

# ============================================================
# IAM: Jenkins User cho ECR Push
# ============================================================
resource "aws_iam_user" "jenkins_ecr" {
  name = "${var.project_name}-${var.environment}-jenkins-ecr"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Purpose     = "Jenkins ECR push access"
  }
}

# Policy cho phép Jenkins push/pull image từ ECR repositories
resource "aws_iam_policy" "jenkins_ecr_policy" {
  name        = "${var.project_name}-${var.environment}-jenkins-ecr-policy"
  description = "Policy cho Jenkins push/pull image lên ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = [
          module.ecr.repository_arns["backend"],
          module.ecr.repository_arns["frontend"]
        ]
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "jenkins_ecr" {
  user       = aws_iam_user.jenkins_ecr.name
  policy_arn = aws_iam_policy.jenkins_ecr_policy.arn
}

# Output credentials info (access key cần tạo thủ công qua AWS Console)
output "jenkins_iam_user" {
  description = "IAM user name cho Jenkins ECR access"
  value       = aws_iam_user.jenkins_ecr.name
}

output "jenkins_ecr_policy_arn" {
  description = "ARN của policy đã attach vào Jenkins IAM user"
  value       = aws_iam_policy.jenkins_ecr_policy.arn
}
