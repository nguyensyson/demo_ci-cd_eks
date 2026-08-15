# ArgoCD Setup Guide

## Overview

This directory contains manifests to install ArgoCD on EKS and configure automatic sync for backend/frontend Helm charts.

## Architecture

```
GitHub Repo ──▶ ArgoCD ──▶ EKS Cluster
                     │
                     ├── demo-backend (helm/backend)
                     └── demo-frontend (helm/frontend)
```

## Prerequisites

- EKS cluster created (from Terraform in `terraform/environments/dev/`)
- kubectl configured with kubeconfig pointing to the EKS cluster
- Git repository with Helm charts at `helm/backend` and `helm/frontend`

## Quick Setup

### 1. Configure kubectl for EKS

```bash
# From terraform output or run manually
aws eks update-kubeconfig --name <CLUSTER_NAME> --region <AWS_REGION>

# Verify connection
kubectl get nodes
```

### 2. Create demo namespace (if not exists)

```bash
kubectl create namespace demo
```

### 3. Install ArgoCD

```bash
# Option A: Install ArgoCD core (recommended for demo)
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Option B: Install HA version (for production)
# kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/ha/install.yaml
```

Wait for ArgoCD pods to be ready:

```bash
kubectl get pods -n argocd -w
```

### 4. Get ArgoCD Admin Password

```bash
# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### 5. Expose ArgoCD UI (Demo Only)

**Option A: kubectl port-forward (Recommended for local demo)**

```bash
# Forward ArgoCD API server to localhost:8080
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open browser: https://localhost:8080
# Login with: admin / <password from step 4>
```

**Option B: LoadBalancer Service (Temporary for demo)**

```bash
# Create a temporary LoadBalancer service (NOTE: This exposes ArgoCD on the internet!)
# FOR DEMO ONLY - Not recommended for production

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
      protocol: TCP
      name: https
  selector:
    app.kubernetes.io/name: argocd-server
EOF

# Get the LoadBalancer hostname
kubectl get svc argocd-server-lb -n argocd

# Access at: https://<LOAD_BALANCER_DNS>
```

**SECURITY WARNING:** The LoadBalancer option exposes ArgoCD directly to the internet.
- Change the default admin password immediately after first login
- Use network policies or security groups to restrict access
- In production, use ingress with authentication (OAuth2 proxy, etc.)

### 6. Update Application Manifests

Before applying, update the placeholder values in the Application manifests:

```bash
# Update with your Git repository URL
REPO_URL="https://github.com/<your-org>/<your-repo>"
sed -i "s|<GIT_REPO_URL>|$REPO_URL|g" application-backend.yaml application-frontend.yaml

# Update with your AWS account info
sed -i "s|<AWS_ACCOUNT_ID>|$(aws sts get-caller-identity --query Account --output text)|g" application-backend.yaml application-frontend.yaml
sed -i "s|<AWS_REGION>|<your-region>|g" application-backend.yaml application-frontend.yaml
```

### 7. Apply ArgoCD Applications

```bash
# Apply backend Application
kubectl apply -f application-backend.yaml

# Apply frontend Application
kubectl apply -f application-frontend.yaml

# Verify Applications are created
kubectl get applications -n argocd
```

### 8. Verify Sync Status

```bash
# Check Application status
argocd app list
# or
kubectl get applications -n argocd

# Get detailed status
argocd app get demo-backend
argocd app get demo-frontend

# Check pods in demo namespace
kubectl get pods -n demo -w
```

## ArgoCD CLI Installation (Optional)

For easier management, install the ArgoCD CLI:

```bash
# macOS
brew install argocd

# Linux
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x /usr/local/bin/argocd

# Login via CLI
argocd login localhost:8080 --username admin --password <PASSWORD> --insecure
```

## Manual Sync (Alternative to Auto-Sync)

If you disabled automated sync, you can sync manually:

```bash
# Sync via CLI
argocd app sync demo-backend
argocd app sync demo-frontend

# Sync via UI: Select app → Actions → Sync
```

## Remaining Manual Steps for Complete Demo

### A. Configure Jenkins Credentials

1. **AWS Credentials:**
   - Go to Jenkins → Manage Jenkins → Credentials → Add Credentials
   - Kind: AWS Credentials
   - ID: `aws-credentials`
   - Fill in Access Key ID and Secret Access Key

2. **ECR Registry:**
   - Install "Amazon ECR" plugin in Jenkins
   - Go to Jenkins → Manage Jenkins → Credentials → Add Credentials
   - Kind: AWS Credentials (same as above) or Docker Registry Credential

3. **GitHub Credentials:**
   - Go to Jenkins → Manage Jenkins → Credentials → Add Credentials
   - Kind: Username with password
   - ID: `github-credentials`
   - Username: GitHub username
   - Password: GitHub Personal Access Token

### B. Create Jenkins Pipeline Job

1. Create a new Pipeline job in Jenkins
2. Configure:
   - Pipeline script from SCM (or Jenkinsfile in repo)
   - SCM: Git
   - Repository URL: `<your-repo-url>`
   - Credentials: `github-credentials`
   - Branch: `*/main`
3. Add build steps for:
   - Build Docker images (backend & frontend)
   - Push to ECR
   - Update Helm values with new image tags (optional)

### C. Update Helm Values After Image Push

After Jenkins builds and pushes images, update the Helm values:

```bash
# Update backend image
helm upgrade --install demo-backend ./helm/backend \
  --namespace demo \
  --set image.repository=<AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com/demo-backend \
  --set image.tag=<BUILD_NUMBER>

# Update frontend image
helm upgrade --install demo-frontend ./helm/frontend \
  --namespace demo \
  --set image.repository=<AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com/demo-frontend \
  --set image.tag=<BUILD_NUMBER>
```

ArgoCD will detect the changes and sync automatically (if automated sync is enabled).

## Troubleshooting

### ArgoCD Application OutOfSync

```bash
# View application diff
argocd app diff demo-backend

# View sync status details
argocd app status demo-backend

# Manual sync
argocd app sync demo-backend --force
```

### ArgoCD Can't Connect to Git

```bash
# Check repository configuration
argocd repo list

# Add repository explicitly
argocd repo add <GIT_REPO_URL> --username <user> --password <token>
```

### Pods Not Starting

```bash
# Check pod events
kubectl describe pod <pod-name> -n demo

# Check pod logs
kubectl logs <pod-name> -n demo

# Check image pull errors
kubectl get events -n demo --field-selector involvedObject.name=<pod-name>
```

### ArgoCD UI Shows "Context Deadline Exceeded"

```bash
# Check ArgoCD server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# Check application controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

## Cleanup

```bash
# Delete ArgoCD Applications
kubectl delete -f application-backend.yaml
kubectl delete -f application-frontend.yaml

# Delete ArgoCD (if no longer needed)
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Delete argocd namespace
kubectl delete namespace argocd

# Delete demo namespace (optional)
kubectl delete namespace demo
```

## Production Considerations

For production deployments, consider:

1. **SSO/RBAC:** Configure ArgoCD with OAuth2 (GitHub, GitLab, Okta, etc.)
2. **Multi-cluster:** ArgoCD can manage multiple clusters from a single instance
3. **ApplicationSets:** Use ApplicationSet for managing many applications
4. **Notifications:** Configure Slack/Teams notifications for sync events
5. **TLS:** Enable TLS termination with cert-manager
6. **Backup:** Regular backup of ArgoCD resources
7. **HA:** Use HA manifest for production workloads
8. **Resource Limits:** Set appropriate resource requests/limits
