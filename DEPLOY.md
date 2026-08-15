# EKS Deployment Guide

## Prerequisites

- AWS account with appropriate permissions
- Existing EKS cluster (1.25+)
- AWS CLI configured
- kubectl with EKS cluster access
- Docker installed locally

---

## Step 1: Create ECR Repositories

Create two ECR repositories for storing Docker images:

```bash
# Set variables
AWS_REGION="us-west-2"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create repositories
aws ecr create-repository --repository-name demo-backend --region $AWS_REGION
aws ecr create-repository --repository-name demo-frontend --region $AWS_REGION

# Get login password and login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
```

---

## Step 2: Build and Push Docker Images

### Backend

```bash
cd backend

# Build image
docker build -t demo-backend:latest .

# Tag for ECR
docker tag demo-backend:latest $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/demo-backend:latest

# Push to ECR
docker push $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/demo-backend:latest

cd ..
```

### Frontend

```bash
cd frontend

# Build image
docker build -t demo-frontend:latest .

# Tag for ECR
docker tag demo-frontend:latest $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/demo-frontend:latest

# Push to ECR
docker push $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/demo-frontend:latest

cd ..
```

---

## Step 3: Update Kubernetes Manifests

Before applying, update the image references in the deployment files:

```bash
# Replace placeholders with actual values
sed -i "s/<ACCOUNT_ID>/$ACCOUNT_ID/g" k8s/backend-deployment.yaml
sed -i "s/<REGION>/$AWS_REGION/g" k8s/backend-deployment.yaml
sed -i "s/<ACCOUNT_ID>/$ACCOUNT_ID/g" k8s/frontend-deployment.yaml
sed -i "s/<REGION>/$AWS_REGION/g" k8s/frontend-deployment.yaml
```

Or manually edit these files:
- `k8s/backend-deployment.yaml`: Replace `<ACCOUNT_ID>` and `<REGION>`
- `k8s/frontend-deployment.yaml`: Replace `<ACCOUNT_ID>` and `<REGION>`

---

## Step 4: Configure kubectl for EKS

```bash
# Update kubeconfig to point to your EKS cluster
aws eks update-kubeconfig --name <CLUSTER_NAME> --region $AWS_REGION

# Verify connection
kubectl get nodes
```

---

## Step 5: Install AWS Load Balancer Controller (if not installed)

```bash
# Download IAM policy
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json

# Create IAM policy
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json

# Get VPC ID of your EKS cluster
VPC_ID=$(aws eks describe-cluster --name <CLUSTER_NAME> --region $AWS_REGION --query cluster.resourcesVpcConfig.vpcId --output text)

# Create IAM service account (replace account IDs)
eksctl create iamserviceaccount \
  --cluster=<CLUSTER_NAME> \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-manual-policy arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve

# Install via Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=<CLUSTER_NAME> \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

---

## Step 6: Apply Kubernetes Manifests

Apply manifests in the correct order:

```bash
# 1. Create namespace
kubectl apply -f k8s/namespace.yaml

# 2. Apply backend resources
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/backend-service.yaml

# 3. Apply frontend resources
kubectl apply -f k8s/frontend-deployment.yaml
kubectl apply -f k8s/frontend-service.yaml

# 4. Apply Ingress (creates ALB)
kubectl apply -f k8s/ingress.yaml

# 5. (Optional) Apply HPA
kubectl apply -f k8s/hpa.yaml
```

---

## Step 7: Verify Deployment

```bash
# Check all resources in demo namespace
kubectl get all -n demo

# Watch pods status
kubectl get pods -n demo -w

# Check services
kubectl get svc -n demo

# Check Ingress (ALB provisioning takes 2-3 minutes)
kubectl get ingress -n demo

# Describe ingress for ALB address
kubectl describe ingress -n demo
```

---

## Step 8: Access the Application

### Get ALB URL

```bash
# Get ALB address
kubectl get ingress -n demo -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'

# Alternative: use kubectl get with wide output
kubectl get ingress -n demo
```

The output will show the ALB DNS name. Open it in your browser.

### Test Backend API Directly

```bash
# Get ALB URL
ALB_URL=$(kubectl get ingress -n demo -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')

# Test health endpoint
curl http://$ALB_URL/api/health

# Test hello endpoint
curl http://$ALB_URL/api/hello
```

---

## Step 9: View Logs

```bash
# Backend logs
kubectl logs -l app=demo-backend -n demo -f

# Frontend logs
kubectl logs -l app=demo-frontend -n demo -f
```

---

## Step 10: Cleanup

```bash
# Delete all resources
kubectl delete -f k8s/namespace.yaml

# Delete ECR repositories (careful - this is irreversible)
aws ecr delete-repository --repository-name demo-backend --region $AWS_REGION --force
aws ecr delete-repository --repository-name demo-frontend --region $AWS_REGION --force
```

---

## Troubleshooting

### Pods not starting

```bash
kubectl describe pod <pod-name> -n demo
kubectl logs <pod-name> -n demo
```

### ImagePullBackOff

```bash
# Verify image exists in ECR
aws ecr describe-repositories
aws ecr list-images --repository-name demo-backend

# Check IAM permissions for ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
```

### ALB not created

```bash
# Check AWS Load Balancer Controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller -f

# Check ingress events
kubectl describe ingress demo-ingress -n demo
```

### HPA not working

```bash
# Check HPA status
kubectl get hpa -n demo

# Enable metrics-server if not installed
kubectl top pods -n demo
```
