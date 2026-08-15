# Helm Charts for Demo CI/CD Pipeline

This directory contains Helm charts for deploying the demo application to EKS.

## Charts

| Chart | Description |
|-------|-------------|
| [backend](backend/) | Backend API service (Spring Boot/Node.js) |
| [frontend](frontend/) | Frontend web application (React/Nginx) |
| [ingress-shared](ingress-shared/) | AWS ALB Ingress for routing traffic |

## Quick Start

### Prerequisites

- Helm 3.x installed
- kubectl configured with EKS cluster access
- ECR repositories created (from Terraform output)

### Installation

1. **Update ECR repository URLs** in each `values.yaml`:

   ```yaml
   # backend/values.yaml
   image:
     repository: <YOUR_ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/demo-backend

   # frontend/values.yaml
   image:
     repository: <YOUR_ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/demo-frontend
   ```

   Or override at install time:
   ```bash
   helm install demo-backend ./helm/backend \
     --set image.repository=<ECR_URL>/demo-backend
   ```

2. **Install charts**:

   ```bash
   # Install in order (backend and frontend first, then ingress)
   helm install demo-backend ./helm/backend -n demo
   helm install demo-frontend ./helm/frontend -n demo
   helm install demo-ingress ./helm/ingress-shared -n demo
   ```

3. **Verify deployment**:

   ```bash
   kubectl get all -n demo
   kubectl get ingress -n demo
   ```

### ArgoCD Integration (Task 4)

For ArgoCD deployment, create Applications pointing to these charts. See Task 4 documentation for details.

## Parameterized Values

### Backend Chart

| Parameter | Description | Default |
|-----------|-------------|---------|
| `namespace` | Target namespace | `demo` |
| `replicaCount` | Number of pods | `2` |
| `image.repository` | ECR image URL | `<ECR_REPO_URL>/demo-backend` |
| `image.tag` | Image tag | `latest` |
| `service.port` | Service port | `80` |
| `service.targetPort` | Container port | `8080` |
| `resources.requests.cpu` | CPU request | `100m` |
| `resources.requests.memory` | Memory request | `128Mi` |
| `resources.limits.cpu` | CPU limit | `200m` |
| `resources.limits.memory` | Memory limit | `256Mi` |
| `autoscaling.enabled` | Enable HPA | `true` |
| `autoscaling.minReplicas` | Min pods | `2` |
| `autoscaling.maxReplicas` | Max pods | `5` |
| `autoscaling.targetCPUUtilizationPercentage` | Target CPU % | `70` |

### Frontend Chart

| Parameter | Description | Default |
|-----------|-------------|---------|
| `namespace` | Target namespace | `demo` |
| `replicaCount` | Number of pods | `2` |
| `image.repository` | ECR image URL | `<ECR_REPO_URL>/demo-frontend` |
| `image.tag` | Image tag | `latest` |
| `service.port` | Service port | `80` |
| `service.targetPort` | Container port | `80` |
| `resources.requests.cpu` | CPU request | `50m` |
| `resources.requests.memory` | Memory request | `64Mi` |
| `resources.limits.cpu` | CPU limit | `100m` |
| `resources.limits.memory` | Memory limit | `128Mi` |

### Ingress Chart

| Parameter | Description | Default |
|-----------|-------------|---------|
| `namespace` | Target namespace | `demo` |
| `ingress.enabled` | Enable ingress | `true` |
| `ingress.className` | Ingress class | `alb` |
| `frontendService.name` | Frontend service name | `demo-frontend-service` |
| `backendService.name` | Backend service name | `demo-backend-service` |

## Validation

```bash
# Lint all charts
helm lint helm/backend helm/frontend helm/ingress-shared

# Template all charts
helm template demo-backend helm/backend
helm template demo-frontend helm/frontend
helm template demo-ingress helm/ingress-shared
```

## File Structure

```
helm/
├── backend/
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── _helpers.tpl
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── hpa.yaml
│       └── NOTES.txt
├── frontend/
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── _helpers.tpl
│       ├── deployment.yaml
│       ├── service.yaml
│       └── NOTES.txt
└── ingress-shared/
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
        ├── _helpers.tpl
        ├── ingress.yaml
        └── NOTES.txt
```

## Migration from legacy YAML

Original Kubernetes manifests are preserved in `../legacy-yaml/` for reference:

- `legacy-yaml/backend-deployment.yaml`
- `legacy-yaml/backend-service.yaml`
- `legacy-yaml/frontend-deployment.yaml`
- `legacy-yaml/frontend-service.yaml`
- `legacy-yaml/ingress.yaml`
- `legacy-yaml/hpa.yaml`
- `legacy-yaml/namespace.yaml`
