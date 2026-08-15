# Demo: Microservice Deployment on Amazon EKS

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              Amazon EKS                                   │
│                                                                         │
│  ┌─────────────┐         ┌─────────────────────────────────────────┐    │
│  │   ALB       │         │              demo namespace              │    │
│  │   (Ingress) │────────▶│                                         │    │
│  └─────────────┘         │  ┌─────────────┐    ┌──────────────┐  │    │
│                          │  │   FE Pod    │    │   FE Pod     │  │    │
│  ┌─────────────┐         │  │  (Nginx)    │    │  (Nginx)     │  │    │
│  │             │────────▶│  └──────┬──────┘    └──────┬───────┘  │    │
│  │             │         │         │                    │        │    │
│  └─────────────┘         │  ┌──────▼──────────────────────────────────▼─│
│                          │  │          FE Service (ClusterIP)           │
│                          │  └──────┬──────────────────────────────────┬──│
│                          │         │                                  │  │
│                          │  ┌──────▼──────┐    ┌──────────────┐       │  │
│                          │  │   BE Pod    │    │   BE Pod     │       │  │
│                          │  │  (Express)  │    │  (Express)   │       │  │
│                          │  └──────┬──────┘    └──────┬───────┘       │  │
│                          │         │                    │              │  │
│                          │  ┌──────▼──────────────────────────────────▼──│
│                          │  │          BE Service (ClusterIP)           │
│                          │  └─────────────────────────────────────────────│
│                          └──────────────────────────────────────────────┘
└─────────────────────────────────────────────────────────────────────────┘
```

## Components

- **Frontend**: Static React app served by Nginx
- **Backend**: Node.js Express API
- **Ingress**: AWS ALB with path-based routing
  - `/` → Frontend Service
  - `/api` → Backend Service

## Quick Start (Local)

```bash
# Start all services
docker compose up -d

# Test backend
curl http://localhost:8080/api/health
curl http://localhost:8080/api/hello

# Test frontend (open in browser)
open http://localhost:3000
```

## Project Structure

```
.
├── backend/               # Node.js Express API
│   ├── src/
│   │   └── index.js      # Main server file
│   ├── Dockerfile        # Multi-stage Docker build
│   └── .dockerignore
├── frontend/             # React + Vite
│   ├── src/
│   │   ├── App.jsx       # Main component
│   │   ├── App.css       # Styling
│   │   ├── main.jsx      # Entry point
│   │   └── config.js     # API configuration
│   ├── nginx.conf        # Nginx configuration
│   ├── Dockerfile        # Multi-stage Docker build
│   └── .dockerignore
├── helm/                 # Helm charts
│   ├── backend/           # Backend Helm chart
│   ├── frontend/          # Frontend Helm chart
│   └── ingress-shared/    # Shared ingress chart
├── terraform/            # Terraform IaC (VPC, EKS, ECR)
│   └── environments/dev/  # Dev environment
├── argocd/                # ArgoCD configuration
│   ├── 00-namespace.yaml
│   ├── 01-install-argocd.yaml
│   ├── application-backend.yaml
│   ├── application-frontend.yaml
│   └── README.md
├── jenkins/              # Jenkins container config
├── docker-compose.yaml
├── DEPLOY.md             # EKS deployment guide
└── README.md
```

## Requirements

- Docker & Docker Compose (for local testing)
- AWS CLI configured with appropriate credentials
- kubectl with EKS cluster access
