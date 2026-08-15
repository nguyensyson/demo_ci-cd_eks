# Terraform Infrastructure - Demo CI/CD EKS

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        AWS Account                               │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  VPC (10.0.0.0/16)                                        │  │
│  │                                                            │  │
│  │  ┌──────────────┐    ┌──────────────────────────────────┐ │  │
│  │  │ Public       │    │ Private Subnets (EKS Nodes)      │ │  │
│  │  │ Subnets      │    │                                  │ │  │
│  │  │              │    │  ┌────────────────────────────┐   │ │  │
│  │  │  ┌─────────┐ │    │  │ demo-app-dev-eks cluster   │   │ │  │
│  │  │  │  NAT    │ │    │  │                            │   │ │  │
│  │  │  │ Gateway │ │    │  │  Node Group: t3.medium    │   │ │  │
│  │  │  └─────────┘ │    │  │  Min:1 | Desired:2 | Max:3 │   │ │  │
│  │  └──────────────┘    │  └────────────────────────────┘   │ │  │
│  │                       └──────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌─────────────────────┐  ┌─────────────────────┐              │
│  │ ECR: backend        │  │ ECR: frontend       │              │
│  │ demo-app-dev-backend│  │ demo-app-dev-frontend│              │
│  └─────────────────────┘  └─────────────────────┘              │
└─────────────────────────────────────────────────────────────────┘
```

## Project Structure

```
terraform/
├── modules/
│   ├── vpc/                 # VPC module (terraform-aws-modules/vpc)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   ├── eks/                 # EKS module (terraform-aws-modules/eks)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   └── ecr/                 # ECR module (custom resources)
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── versions.tf
│
├── environments/
│   └── dev/
│       ├── main.tf          # Gọi các module
│       ├── variables.tf
│       ├── outputs.tf
│       ├── terraform.tfvars
│       ├── backend.tf       # Backend config (local/S3)
│       └── versions.tf
│
└── README.md
```

## Modules

### Module: VPC (`modules/vpc`)

Tạo VPC với public và private subnets.

| Output | Mô tả |
|--------|--------|
| `vpc_id` | VPC ID |
| `vpc_cidr_block` | VPC CIDR |
| `private_subnet_ids` | Private subnets cho EKS |
| `public_subnet_ids` | Public subnets cho ALB |

**Cấu hình:**
- 2 AZ: `ap-southeast-1a`, `ap-southeast-1b`
- Single NAT Gateway (tối ưu chi phí demo)
- DNS hostnames và support enabled

**Trade-off:** Single NAT Gateway = nếu NAT GW bị down, egress traffic fail. Production nên dùng 1 NAT GW mỗi AZ.

### Module: EKS (`modules/eks`)

Tạo EKS cluster với managed node group.

| Output | Mô tả |
|--------|--------|
| `cluster_name` | Tên cluster |
| `cluster_endpoint` | API server URL |
| `cluster_certificate_authority_data` | CA cert cho kubectl |
| `oidc_provider_arn` | IAM OIDC provider (IRSA) |

**Cấu hình:**
- Kubernetes: 1.30
- Node type: t3.medium
- Node count: Min 1, Desired 2, Max 3
- Public endpoint access enabled

**Lưu ý:** Endpoint public access = true cho demo. Production nên:
- `cluster_endpoint_private_access = true`
- `cluster_endpoint_public_access = true` với `public_access_cidrs` giới hạn

### Module: ECR (`modules/ecr`)

Tạo ECR repositories cho Docker images.

| Output | Mô tả |
|--------|--------|
| `repository_urls` | Map tên -> URL (backend, frontend) |

**Repositories:**
- `demo-app-dev-backend`
- `demo-app-dev-frontend`

**Cấu hình:**
- Image scanning on push enabled
- Tag mutability: MUTABLE
- Lifecycle policy: giữ 10 tags gần nhất

## Quick Start

### 1. Initialize Terraform

```bash
cd terraform/environments/dev
terraform init
```

### 2. Plan và Apply

```bash
# Xem kế hoạch
terraform plan

# Apply infrastructure
terraform apply
```

### 3. Configure kubectl

```bash
# Sau khi apply thành công, chạy:
aws eks update-kubeconfig --name demo-app-dev-eks --region ap-southeast-1
```

### 4. Verify cluster

```bash
kubectl get nodes
kubectl get ns
```

## Outputs

Sau khi apply, các outputs quan trọng:

```
cluster_name = "demo-app-dev-eks"
cluster_endpoint = "https://<endpoint>.eks.amazonaws.com"
eks_config_command = "aws eks update-kubeconfig --name demo-app-dev-eks --region ap-southeast-1"
repository_urls = {
  "backend" = "<account>.dkr.ecr.ap-southeast-1.amazonaws.com/demo-app-dev-backend"
  "frontend" = "<account>.dkr.ecr.ap-southeast-1.amazonaws.com/demo-app-dev-frontend"
}
```

## Mở rộng: Thêm môi trường mới

```bash
# Tạo thư mục staging
mkdir -p terraform/environments/staging

# Copy và điều chỉnh terraform.tfvars
cp environments/dev/main.tf environments/staging/
cp environments/dev/variables.tf environments/staging/
cp environments/dev/outputs.tf environments/staging/
cp environments/dev/backend.tf environments/staging/
cp environments/dev/versions.tf environments/staging/

# Sửa terraform.tfvars
# environment = "staging"
# desired_size = 3 (hoặc production: 5+)
```

## Backend: Local vs S3

### Local (Demo)
```hcl
terraform {
  # Mặc định dùng local
}
```
State file: `terraform/environments/dev/terraform.tfstate`

### S3 + DynamoDB (Production/Team)
```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "terraform/dev/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

## Resource Summary

| Resource | Module | Description |
|----------|--------|-------------|
| VPC | vpc | 1 VPC, 4 subnets (2 public, 2 private) |
| Internet Gateway | vpc | 1 IGW |
| NAT Gateway | vpc | 1 NAT GW |
| Route Tables | vpc | 2 route tables |
| EKS Cluster | eks | 1 EKS cluster |
| EKS Node Group | eks | 1 managed node group (t3.medium x 2) |
| IAM OIDC Provider | eks | 1 OIDC provider cho IRSA |
| ECR Repositories | ecr | 2 repositories (backend, frontend) |
| ECR Lifecycle Policy | ecr | 2 lifecycle policies |

## Chi phí Ước tính (tháng)

| Resource | Chi phí ước tính |
|----------|-------------------|
| NAT Gateway | ~$32/tháng |
| EKS Cluster | Miễn phí |
| EC2 t3.medium x 2 | ~$30/tháng |
| ECR Storage | ~$0.01/GB/tháng |
| **Tổng** | **~$62/tháng** |

## Cleanup

```bash
# Xóa toàn bộ infrastructure
terraform destroy
```
