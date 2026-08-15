module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-${var.environment}-vpc"
  cidr = var.vpc_cidr

  # Số AZ tối thiểu cho EKS (2 AZ để spread node)
  azs = var.availability_zones

  # Public subnets cho ALB/NAT Gateway
  public_subnets = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 4, i)]

  # Private subnets cho EKS nodes và workloads
  private_subnets = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 4, i + length(var.availability_zones))]

  # Single NAT Gateway cho demo (tối ưu chi phí)
  # Trade-off: Nếu AZ của NAT GW bị down, egress traffic từ private subnet sang internet sẽ fail
  # Production nên dùng: nat_gateways = length(var.availability_zones) cho HA
  single_nat_gateway = true
  enable_nat_gateway = true

  # DNS - bắt buộc cho EKS
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags chung
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  # Tags bắt buộc cho AWS Load Balancer Controller
  # Public subnet: ALB public cần tag này để LB Controller discover
  public_subnet_tags = merge({
    "kubernetes.io/role/elb" = "1"
    }, var.cluster_name != "" ? {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  } : {})

  # Private subnet: Internal ALB cần tag này
  private_subnet_tags = merge({
    "kubernetes.io/role/internal-elb" = "1"
    }, var.cluster_name != "" ? {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  } : {})
}
