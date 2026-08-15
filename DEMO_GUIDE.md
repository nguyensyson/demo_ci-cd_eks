# Demo CI/CD Pipeline Guide

## GitHub → Jenkins → ECR → ArgoCD → EKS

Hướng dẫn chi tiết từng bước để setup và chạy demo CI/CD pipeline hoàn chỉnh.

---

## 📋 Mục lục

1. [Tổng quan kiến trúc](#tổng-quan-kiến-trúc)
2. [Yêu cầu hệ thống](#yêu-cầu-hệ-thống)
3. [Bước 1: Terraform - Tạo hạ tầng AWS](#bước-1-terraform---tạo-hạ-tầng-aws)
4. [Bước 2: Cài đặt Jenkins](#bước-2-cài-đặt-jenkins)
5. [Bước 3: ArgoCD - GitOps Controller](#bước-3-argocd---gitops-controller)
6. [Bước 4: Cấu hình GitHub Webhook](#bước-4-cấu-hình-github-webhook)
7. [Bước 5: Chạy Demo Pipeline](#bước-5-chạy-demo-pipeline)
8. [Xác minh & Troubleshooting](#xác-minh--troubleshooting)
9. [Dọn dẹp](#dọn-dẹp)

---

## Tổng quan kiến trúc

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              DEMO CI/CD PIPELINE                                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│   ┌─────────┐      ┌────────────┐      ┌──────┐      ┌─────────┐      ┌─────┐│
│   │ GitHub  │─────▶│  Jenkins   │─────▶│ ECR  │─────▶│ ArgoCD  │─────▶│ EKS ││
│   │  Repo   │      │ Build/Push │      │ Repo │      │  Sync   │      │     ││
│   └─────────┘      └────────────┘      └──────┘      └─────────┘      └─────┘│
│       │                  │                                    │                 │
│       │                  │                                    │                 │
│   Source Code      Docker Images                       Helm Charts             │
│   Helm Charts      (backend + frontend)                (git state)            │
│                                                                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                    AWS                                            │
│   ┌──────────────────────────────────────────────────────────────────────────┐   │
│   │                        Amazon EKS Cluster                                 │   │
│   │   ┌─────────────┐                    ┌─────────────┐                    │   │
│   │   │ demo-backend│                    │demo-frontend│                    │   │
│   │   │   (Pod)     │                    │   (Pod)     │                    │   │
│   │   └─────────────┘                    └─────────────┘                    │   │
│   └──────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
│   ┌──────────────────────────────────────────────────────────────────────────┐   │
│   │                         Amazon ECR                                        │   │
│   │   ┌─────────────────┐         ┌─────────────────┐                       │   │
│   │   │ demo-backend    │         │ demo-frontend   │                       │   │
│   │   │ (Docker Image)  │         │ (Docker Image)  │                       │   │
│   │   └─────────────────┘         └─────────────────┘                       │   │
│   └──────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Flow chi tiết:

1. **Developer push code** → GitHub repo
2. **GitHub Webhook** → Trigger Jenkins job
3. **Jenkins Pipeline**:
   - Build Docker images (backend + frontend)
   - Push lên Amazon ECR
   - Update Helm values với image tag mới
   - Commit & push Helm values lên git
4. **ArgoCD**:
   - Phát hiện thay đổi trong git
   - Tự động sync Helm charts vào EKS
5. **EKS**:
   - Pull images từ ECR
   - Deploy pods (backend + frontend)

---

## Yêu cầu hệ thống

### Tools cần thiết

```bash
# AWS CLI
aws --version  # >= 2.x

# Terraform
terraform --version  # >= 1.0

# kubectl
kubectl version --client  # >= 1.25

# Docker
docker --version  # >= 20.x

# Git
git --version
```

### Tài khoản AWS

- AWS Account với quyền tạo: VPC, EKS, ECR, IAM
- AWS Credentials configured locally (`aws configure`)

### Môi trường

- **OS**: Linux/macOS/Windows (WSL2 recommended for Windows)
- **RAM**: Tối thiểu 8GB (Jenkins cần ~2GB)
- **Disk**: Tối thiểu 20GB free

---

## Bước 1: Terraform - Tạo hạ tầng AWS

### 1.1 Di chuyển vào thư mục Terraform

```bash
cd terraform/environments/dev
```

### 1.2 Khởi tạo Terraform

```bash
terraform init
```

Output mong đợi:
```
Initializing the backend...
Initializing provider plugins...
- Finding aws versions matching "~> 5.0"...
Terraform has been successfully initialized!
```

### 1.3 Plan infrastructure

```bash
terraform plan -out=tfplan
```

Resources sẽ được tạo:
- VPC với 2 private + 2 public subnets
- EKS cluster (1.30)
- ECR repositories (demo-backend, demo-frontend)
- IAM user cho Jenkins (demo-app-dev-jenkins-ecr)

### 1.4 Apply infrastructure

```bash
terraform apply tfplan
```

**⏱️ Thời gian: ~15-20 phút**

### 1.5 Lấy outputs quan trọng

```bash
# Lấy tất cả outputs
terraform output

# Cluster name
CLUSTER_NAME=$(terraform output -raw cluster_name)

# ECR URLs
BACKEND_ECR=$(terraform output -raw repository_urls | jq -r '.backend')
FRONTEND_ECR=$(terraform output -raw repository_urls | jq -r '.frontend')

# kubectl config command
terraform output eks_config_command
```

### 1.6 Configure kubectl

```bash
# Chạy command từ terraform output
aws eks update-kubeconfig --name demo-app-dev-eks --region ap-southeast-1

# Verify
kubectl get nodes
```

### 1.7 Tạo Jenkins IAM User Access Key

⚠️ **Bước này cần làm thủ công qua AWS Console:**

1. Go to AWS Console → IAM → Users
2. Find user: `demo-app-dev-jenkins-ecr`
3. Security credentials → Create access key
4. **Lưu lại Access Key ID và Secret Access Key** (sẽ cần cho Jenkins)

---

## Bước 2: Cài đặt Jenkins

### 2.1 Khởi động Jenkins với Docker Compose

```bash
# Từ thư mục gốc project
cd demo-ci-cd-eks
docker compose up -d jenkins
```

### 2.2 Chờ Jenkins khởi động

```bash
# Kiểm tra status
docker compose ps jenkins

# Xem logs
docker compose logs -f jenkins
```

### 2.3 Truy cập Jenkins UI

```
URL: http://localhost:9090
```

### 2.4 Unlock Jenkins (lần đầu)

```bash
# Lấy initial admin password
docker compose exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

1. Mở http://localhost:9090
2. Dán password
3. Click **Install suggested plugins**
4. Tạo admin user

### 2.5 Cài đặt Plugins cần thiết

1. Go to **Manage Jenkins** → **Manage Plugins**
2. Tab **Available**: Cài đặt:
   - **Amazon ECR** - Cho ECR integration
   - **Pipeline** - Cho Jenkinsfile
   - **Git** - Cho Git integration
   - **Docker Pipeline** - Cho docker commands trong pipeline

### 2.6 Cấu hình AWS Credentials

1. Go to **Manage Jenkins** → **Credentials** → **System** → **Add Credentials**
2. Kind: **AWS Credentials**
3. ID: `aws-ecr-credentials`
4. Access Key ID: `<từ bước 1.7>`
5. Secret Access Key: `<từ bước 1.7>`
6. Click **OK**

### 2.7 Cấu hình GitHub Credentials

1. **Manage Jenkins** → **Credentials** → **System** → **Add Credentials**
2. Kind: **Username with password**
3. ID: `github-credentials`
4. Username: `<GitHub username>`
5. Password: `<GitHub Personal Access Token>`
6. Click **OK**

### 2.8 Tạo Jenkins Pipeline Job

1. Click **New Item**
2. Enter name: `demo-ci-cd-pipeline`
3. Select **Pipeline** → Click **OK**
4. Configure:

**General Tab:**
- ☑️ GitHub project
- Project URL: `https://github.com/<your-org>/<your-repo>/`

**Pipeline Tab:**
- Definition: **Pipeline script from SCM**
- SCM: **Git**
- Repository URL: `https://github.com/<your-org>/<your-repo>.git`
- Credentials: `github-credentials`
- Branch: `*/main`
- Script Path: `Jenkinsfile` (hoặc tạo Jenkinsfile trong repo)

---

## Bước 3: ArgoCD - GitOps Controller

### 3.1 Cài đặt ArgoCD lên EKS

```bash
# Tạo namespace argocd
kubectl create namespace argocd

# Cài ArgoCD (core components)
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### 3.2 Chờ ArgoCD pods ready

```bash
kubectl get pods -n argocd -w
```

Đợi tất cả pods ở trạng thái **Running**.

### 3.3 Lấy ArgoCD Admin Password

```bash
# Get password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Lưu lại password này
```

### 3.4 Truy cập ArgoCD UI

**Option A: Port-forward (Recommended cho demo)**

```bash
# Terminal 1: Keep this running
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open browser: https://localhost:8080
# Login: admin / <password from step 3.3>
```

**Option B: LoadBalancer (Temporary demo)**

```bash
# ⚠️ FOR DEMO ONLY - Exposes ArgoCD to internet
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: argocd-server-lb
  namespace: argocd
spec:
  type: LoadBalancer
  ports:
    - port: 443
      targetPort: 8080
  selector:
    app.kubernetes.io/name: argocd-server
EOF

# Get LoadBalancer DNS
kubectl get svc argocd-server-lb -n argocd
```

### 3.5 Cập nhật Application Manifests

```bash
# Update Git repo URL
REPO_URL="https://github.com/<your-org>/<your-repo>.git"
sed -i "s|<GIT_REPO_URL>|$REPO_URL|g" argocd/application-backend.yaml
sed -i "s|<GIT_REPO_URL>|$REPO_URL|g" argocd/application-frontend.yaml

# Update AWS account info
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
sed -i "s|<AWS_ACCOUNT_ID>|$AWS_ACCOUNT|g" argocd/application-backend.yaml
sed -i "s|<AWS_ACCOUNT_ID>|$AWS_ACCOUNT|g" argocd/application-frontend.yaml

sed -i "s|<AWS_REGION>|ap-southeast-1|g" argocd/application-backend.yaml
sed -i "s|<AWS_REGION>|ap-southeast-1|g" argocd/application-frontend.yaml
```

### 3.6 Apply ArgoCD Applications

```bash
# Apply backend Application
kubectl apply -f argocd/application-backend.yaml

# Apply frontend Application
kubectl apply -f argocd/application-frontend.yaml

# Verify Applications
kubectl get applications -n argocd
```

---

## Bước 4: Cấu hình GitHub Webhook

### 4.1 Lấy Jenkins Webhook URL

```
http://localhost:9090/generic-webhook-trigger/invoke
```

### 4.2 Thêm Webhook trong GitHub

1. Go to GitHub repo → **Settings** → **Webhooks** → **Add webhook**
2. Payload URL: `http://<your-ip>:9090/generic-webhook-trigger/invoke`
3. Content type: `application/json`
4. Events: **Just the push event**
5. Click **Add webhook**

---

## Bước 5: Chạy Demo Pipeline

### 5.1 Trigger Pipeline

**Option A: Push code lên GitHub**
```bash
# Make a change to any file
git add .
git commit -m "Trigger CI/CD pipeline"
git push origin main
```

**Option B: Trigger manually trong Jenkins**
1. Open Jenkins: http://localhost:9090
2. Click vào `demo-ci-cd-pipeline`
3. Click **Build Now**

### 5.2 Theo dõi Pipeline

```bash
# Xem Jenkins logs
docker compose logs -f jenkins

# Theo dõi ArgoCD sync
kubectl get applications -n argocd -w
```

### 5.3 Xem Kubernetes Resources

```bash
# Check pods
kubectl get pods -n demo -w

# Check services
kubectl get svc -n demo

# Check ArgoCD apps
argocd app list  # Nếu cài ArgoCD CLI
```

---

## Xác minh & Troubleshooting

### Check EKS cluster

```bash
kubectl get nodes
kubectl get pods -A
```

### Check ArgoCD Applications

```bash
# ArgoCD CLI
argocd app list
argocd app get demo-backend
argocd app get demo-frontend

# kubectl
kubectl get applications -n argocd
```

### Check Images trong ECR

```bash
# List ECR repositories
aws ecr describe-repositories --region ap-southeast-1

# List images
aws ecr list-images --repository-name demo-backend --region ap-southeast-1
aws ecr list-images --repository-name demo-frontend --region ap-southeast-1
```

### Check Jenkins Pipeline

```bash
# Xem logs
docker compose logs jenkins

# Kiểm tra containers
docker compose ps
```

### Common Issues

**Issue: ArgoCD "ComparisonFailed"**
```bash
# Xem chi tiết
argocd app diff demo-backend

# Sync manually
argocd app sync demo-backend --force
```

**Issue: ImagePullBackOff**
```bash
# Kiểm tra ECR login
aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin <account>.dkr.ecr.ap-southeast-1.amazonaws.com

# Verify image exists
aws ecr describe-images --repository-name demo-backend --region ap-southeast-1
```

**Issue: Jenkins can't connect to GitHub**
```bash
# Kiểm tra credentials
curl -I https://github.com

# Verify PAT token has correct permissions
```

---

## Dọn dẹp

### Xóa Kubernetes Resources

```bash
# ArgoCD Applications
kubectl delete -f argocd/application-backend.yaml
kubectl delete -f argocd/application-frontend.yaml

# ArgoCD
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl delete namespace argocd

# Demo namespace
kubectl delete namespace demo
```

### Xóa AWS Infrastructure

```bash
cd terraform/environments/dev

# Destroy all AWS resources
terraform destroy

# Type 'yes' when prompted
```

### Dừng Jenkins

```bash
docker compose down
```

### Xóa ECR Images (optional)

```bash
aws ecr batch-delete-image --repository-name demo-backend --image-ids imageTag=latest --region ap-southeast-1
aws ecr batch-delete-image --repository-name demo-frontend --image-ids imageTag=latest --region ap-southeast-1
```

---

## File Structure

```
demo-ci-cd-eks/
├── backend/                    # Node.js Express API
│   ├── src/index.js
│   ├── package.json
│   └── Dockerfile
├── frontend/                   # React + Vite
│   ├── src/
│   ├── package.json
│   ├── Dockerfile
│   └── nginx.conf
├── helm/                       # Helm Charts
│   ├── backend/
│   ├── frontend/
│   └── ingress-shared/
├── terraform/                  # Infrastructure as Code
│   └── environments/dev/
│       ├── main.tf
│       ├── variables.tf
│       └── terraform.tfvars
├── jenkins/                    # Jenkins Docker config
│   └── Dockerfile
├── argocd/                     # ArgoCD Configuration
│   ├── 00-namespace.yaml
│   ├── 01-install-argocd.yaml
│   ├── application-backend.yaml
│   ├── application-frontend.yaml
│   └── README.md
├── docker-compose.yaml
├── DEMO_GUIDE.md              # This file
├── DEPLOY.md
└── README.md
```

---

## Quick Reference

### Essential Commands

```bash
# Terraform
cd terraform/environments/dev && terraform init && terraform apply

# kubectl
aws eks update-kubeconfig --name demo-app-dev-eks --region ap-southeast-1
kubectl get nodes
kubectl get pods -A

# ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443
argocd app list

# Docker
docker compose up -d
docker compose logs -f
```

### URLs

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| Jenkins | http://localhost:9090 | admin / `<initial-password>` |
| ArgoCD | https://localhost:8080 | admin / `<argocd-password>` |
| Backend API | http://localhost:8080/api/health | - |
| Frontend | http://localhost:3000 | - |

---

## Next Steps

Sau khi demo hoạt động, có thể mở rộng:

1. **Production-grade setup**:
   - ArgoCD SSO với OAuth2 (GitHub, Okta)
   - TLS với cert-manager
   - Multi-environment (staging, production)

2. **CI/CD improvements**:
   - ArgoCD Image Updater cho auto-sync image tags
   - Jenkins Blue Ocean cho visual pipeline
   - Slack/Teams notifications

3. **Security**:
   - RBAC policies
   - Network policies
   - Secret management (AWS Secrets Manager, HashiCorp Vault)

4. **Monitoring**:
   - Prometheus + Grafana
   - AWS CloudWatch Container Insights
   - ArgoCD Notifications
