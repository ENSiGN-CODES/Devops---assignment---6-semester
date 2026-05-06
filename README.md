# CSET 452 — DevOps Assignment
## Fintech Microservices on AWS — Complete Infrastructure

---

## Application Overview

A fintech web application with:
- **Backend:** Node.js (Express) REST API connected to PostgreSQL
- **Frontend:** HTML/JS served via Nginx
- **Database:** PostgreSQL (RDS on AWS)
- **Cache:** Redis (ElastiCache on AWS)

### API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/health` | Health check (used by K8s probes) |
| GET | `/api/users` | List all users |
| POST | `/api/users` | Add a new user |

---

## Repository Structure

```
.
├── app/
│   ├── backend/
│   │   ├── server.js          ← Express API (Node.js)
│   │   └── package.json       ← Dependencies
│   └── frontend/
│       └── index.html         ← HTML/JS frontend
│
├── docker/
│   ├── backend/Dockerfile     ← Multi-stage Node.js image (port 3000)
│   └── frontend/Dockerfile    ← Nginx static file server (port 80)
│
├── terraform/                 ← AWS infrastructure (IaC)
│   ├── terraform.tfvars       ← ALL variables centralized here (single source of truth)
│   ├── variables.tf           ← Variable declarations
│   ├── main.tf                ← Module wiring
│   ├── provider.tf            ← AWS provider + multi-region aliases
│   ├── backend.tf             ← S3 remote state + DynamoDB lock
│   ├── outputs.tf
│   └── modules/
│       ├── vpc/               ← VPC, subnets, NAT (terraform-aws-modules/vpc)
│       ├── eks/               ← Kubernetes cluster (terraform-aws-modules/eks)
│       ├── rds/               ← PostgreSQL (terraform-aws-modules/rds)
│       └── redis/             ← ElastiCache (terraform-aws-modules/elasticache)
│
├── kubernetes/                ← K8s manifests (managed by Argo CD)
│   ├── backend/
│   │   ├── deployment.yaml    ← RollingUpdate + readinessProbe on /api/health:3000
│   │   ├── service.yaml       ← ClusterIP port 3000
│   │   └── hpa.yaml           ← CPU/memory autoscaling
│   ├── frontend/
│   │   └── deployment.yaml    ← Nginx deployment + service
│   ├── database/
│   │   └── secret.yaml        ← K8s Secrets + External Secrets Operator
│   ├── ingress.yaml           ← ALB Ingress Controller
│   └── argocd-application.yaml ← GitOps config
│
├── .github/workflows/
│   ├── ci-cd.yml              ← Build→Test→Push→Deploy (4 stages)
│   └── rollback.yml           ← Manual rollback to any image tag
│
└── architecture-docs/
    └── FULL_DESIGN_ANSWERS.md ← All 6 assignment parts answered
```

---

## Infrastructure Stack

| Component | Technology | Registry Module |
|-----------|-----------|----------------|
| Cloud | AWS | — |
| IaC | Terraform 1.5+ | — |
| VPC | AWS VPC | terraform-aws-modules/vpc/aws v5.8.1 |
| Kubernetes | EKS 1.27 | terraform-aws-modules/eks/aws v20.8.4 |
| Database | RDS PostgreSQL 14 | terraform-aws-modules/rds/aws v6.6.0 |
| Cache | ElastiCache Redis 7.1 | terraform-aws-modules/elasticache/aws v1.2.2 |
| CI/CD | GitHub Actions + Argo CD | — |
| Container Registry | Amazon ECR | — |

---

## Key Design Decisions

- **`terraform.tfvars` is the single source of truth** — change any value once, propagates everywhere
- **Zero-downtime deploys** via RollingUpdate + readinessProbe on `/api/health`
- **No hardcoded secrets** — all credentials via Kubernetes Secrets from AWS Secrets Manager
- **Multi-AZ** VPC (2 AZs), Multi-AZ RDS, Redis with replica
- **GitOps** — Argo CD auto-syncs from this repo; Git is always source of truth

---

## See `architecture-docs/FULL_DESIGN_ANSWERS.md` for detailed answers to all 6 parts (a–f).
