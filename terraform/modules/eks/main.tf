module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${var.project_name}-${var.environment}-eks"
  cluster_version = var.cluster_version

  # VPC config
  vpc_id                          = var.vpc_id
  subnet_ids                      = var.private_subnet_ids
  cluster_endpoint_private_access = false
  cluster_endpoint_public_access  = true
  # Note: endpoint_public_access = true cho demo. Thực tế nên giới hạn CIDR:
  # public_access_cidrs = ["10.0.0.0/8"] hoặc dùng private endpoint + VPN/bastion

  # EKS addons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  # Managed node group
  eks_managed_node_groups = {
    default = {
      name = "default-nodes"

      instance_type = "t3.medium"
      desired_size  = 2
      min_size      = 1
      max_size      = 3

      labels = {
        role = "general"
      }

      # Đặt taint để workload có thể dùng nodeSelector/tolerations
      taints = []
    }
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# IAM OIDC Provider cho IRSA (Kubernetes Service Account -> AWS IAM)
resource "aws_iam_openid_connect_provider" "eks_oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = []
  url             = module.eks.cluster_oidc_issuer_url
}
