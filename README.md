# CSET 452 – DevOps Assignment
## Fintech Microservices: Design & Deployment

**Course:** CSET 452 – DevOps  
**Marks:** 20

---

## Project Overview

This repository contains the architecture design, infrastructure code, Dockerfiles, Kubernetes manifests, and CI/CD pipeline configuration for a fintech application consisting of:

- **Backend** – Node.js/Express REST API (port 3000)
- **Frontend** – Static HTML/JS UI served via Nginx (port 80)
- **Database** – PostgreSQL (RDS on AWS)

---

## Repository Structure
fintech-devops/
├── backend/
│   ├── server.js
│   ├── package.json
│   └── Dockerfile
├── frontend/
│   ├── index.html
│   └── Dockerfile
├── k8s/
│   ├── backend-deployment.yaml
│   ├── frontend-deployment.yaml
│   ├── hpa.yaml
│   └── secret.yaml
├── .github/
│   └── workflows/
│       └── ci-cd.yaml
└── README.md

---

## (a) Architecture Design (4 Marks)

### VPC Structure

The AWS VPC spans **2 Availability Zones** (us-east-1a, us-east-1b) with the following subnet layout:

| Subnet Type | AZ-1 (us-east-1a) | AZ-2 (us-east-1b) |
|---|---|---|
| Public | 10.0.1.0/24 | 10.0.2.0/24 |
| Private (App) | 10.0.11.0/24 | 10.0.12.0/24 |
| Private (DB) | 10.0.21.0/24 | 10.0.22.0/24 |

- **Public subnets** host only the Application Load Balancer (ALB) and NAT Gateways. No application workloads are exposed directly to the internet.
- **Private app subnets** host EKS worker nodes. Outbound internet access goes through the NAT Gateway (for pulling images etc).
- **Private DB subnets** host RDS PostgreSQL and Redis (ElastiCache). These have absolutely no internet route.

**Why this structure?** Defense in depth — even if the ALB is compromised, attackers cannot directly reach the database because there is no network route between public and DB subnets.

### Service Placement

| Service | Placement | Reason |
|---|---|---|
| ALB (Ingress) | Public subnets | Must accept internet traffic |
| EKS Worker Nodes | Private app subnets | Workers don't need public IPs |
| RDS PostgreSQL | Private DB subnets | Database must never be internet-facing |
| Redis (ElastiCache) | Private DB subnets | Cache/session data is sensitive |
| ECR | AWS-managed | Container registry, no placement needed |

### Load Balancing

We use **AWS ALB** with the **Kubernetes Nginx Ingress Controller**:
- ALB terminates HTTPS using ACM certificates
- Forwards traffic to the Nginx Ingress inside the cluster
- Ingress routes `/api/*` → backend service and `/*` → frontend service

This means one ALB handles both services instead of two separate load balancers — saving cost.

### Multi-Region Design

We use an **active-passive** strategy across two regions:

- **Primary region (us-east-1):** Handles all live traffic
- **Secondary region (us-west-2):** Warm standby — EKS runs at minimum capacity (1 node), RDS has a read replica ready
- **Route 53** performs health-check-based DNS failover. If the primary ALB fails health checks for 30 seconds, Route 53 automatically redirects traffic to the secondary ALB.

### High Availability Strategy

- Minimum **2 pod replicas** for every service, spread across 2 AZs
- RDS configured with **Multi-AZ** (synchronous standby in same region)
- RDS **read replica** in us-west-2 for cross-region failover
- ALB health checks + Kubernetes readiness probes ensure traffic only goes to healthy pods

### Security Considerations

- All inter-service traffic stays inside the VPC — no public endpoints for DB or Redis
- Security Groups follow least-privilege: backend pods can only reach RDS on port 5432, frontend pods can only reach backend on port 3000
- DB credentials stored in **AWS Secrets Manager**, never in code or environment variables
- TLS terminated at the ALB using ACM certificates
- Kubernetes Network Policies restrict pod-to-pod communication

### Cost Trade-offs

| Decision | Cost Impact | Reason |
|---|---|---|
| Active-passive (not active-active) | Lower — secondary runs minimal nodes | Active-active doubles RDS and EKS costs with no benefit for a startup |
| Single ALB for both services | Saves ~$20/month | Two ALBs would be wasteful for one app |
| Alpine base images | Smaller ECR storage bills | Less data transferred per deployment |
| HPA min 2 replicas | Small fixed cost | Necessary for AZ redundancy, worth it |

---

## (b) Terraform Strategy (4 Marks)

### Module Design
terraform/
├── modules/
│   ├── vpc/        # VPC, subnets, IGW, NAT, route tables
│   ├── eks/        # EKS cluster, node groups, IAM roles
│   ├── rds/        # RDS PostgreSQL, subnet group, parameter group
│   └── redis/      # ElastiCache Redis, subnet group
├── environments/
│   ├── dev/
│   │   └── main.tf
│   ├── staging/
│   │   └── main.tf
│   └── prod/
│       └── main.tf

Each module has one responsibility. The `vpc` module outputs subnet IDs and VPC ID, which the `eks` and `rds` modules take as inputs. This explicit dependency chain means Terraform always creates the VPC before EKS — no manual ordering needed.

**Why separate modules and not one big file?** Each module can be tested independently, reused across environments, and reviewed separately in pull requests. A 500-line monolith file is impossible to review safely.

### Remote State Management

```hcl
terraform {
  backend "s3" {
    bucket         = "fintech-tfstate-prod"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

- **S3** stores the state file with versioning enabled — allows rollback if state gets corrupted
- **DynamoDB** provides state locking — prevents two engineers running `terraform apply` at the same time and corrupting state
- State is **encrypted at rest** using S3 server-side encryption

### Environment Separation

We use **folder-based separation** (not Terraform workspaces) because:
- Workspaces share the same backend config, making it easy to accidentally apply prod changes from a dev terminal
- Separate folders in `environments/` with their own `terraform.tfvars` make the separation explicit and hard to accidentally cross

Each environment has its own S3 key (`dev/terraform.tfstate`, `prod/terraform.tfstate`) and its own DynamoDB lock entry.

### Multi-Region Handling

```hcl
provider "aws" {
  alias  = "primary"
  region = "us-east-1"
}

provider "aws" {
  alias  = "secondary"
  region = "us-west-2"
}

module "eks_primary" {
  source    = "../../modules/eks"
  providers = { aws = aws.primary }
}

module "eks_secondary" {
  source    = "../../modules/eks"
  providers = { aws = aws.secondary }
}
```

### Dependency Handling

- VPC module runs first → outputs subnet IDs
- EKS and RDS modules declare `depends_on` the VPC module
- Terraform builds a dependency graph automatically and provisions in the correct order

### Challenges

| Challenge | How We Handle It |
|---|---|
| State drift (someone changes AWS manually via Console) | Run `terraform plan` in CI on every PR — detects drift before it causes issues |
| Region sync (both regions must stay identical) | Pin module `source` to a specific Git tag, not a branch |
| RDS failover promotion | Terraform creates the replica, but promotion during a live outage is triggered by a Lambda function — Terraform doesn't manage live failover events |

---

## (c) Docker & Image Strategy (3 Marks)

### Optimized Backend Dockerfile (Multi-stage)

```dockerfile
# Stage 1: Install dependencies
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Stage 2: Final image
FROM node:20-alpine
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY server.js .

RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

EXPOSE 3000
CMD ["node", "server.js"]
```

### How We Reduce Image Size and Vulnerabilities

| Technique | What It Does |
|---|---|
| Multi-stage build | Build tools (gcc, make) are used in Stage 1 but never copied to the final image — cuts size by ~60% |
| Alpine base image | ~5MB vs ~170MB for Debian — fewer packages means fewer CVEs |
| Non-root user | If an attacker exploits the app, they get a user with no privileges — limits damage |
| `npm ci --only=production` | Dev dependencies (jest, eslint etc) are never installed in the production image |

### Image Versioning Strategy

Every CI build produces three tags:

| Tag | Example | Purpose |
|---|---|---|
| Git commit SHA | `backend:a3f9c12` | Exact traceability — know exactly which code is running |
| Semantic version | `backend:1.4.2` | Human-readable release tracking |
| `latest` | `backend:latest` | Convenience for local dev only, never used in production |

Images are stored in **Amazon ECR**. ECR is in the same AWS account as EKS, so nodes pull images without going through the internet — faster pulls and no egress cost. ECR lifecycle policies delete untagged images older than 30 days automatically.

### CI/CD Integration

On every merge to `main`:
1. GitHub Actions builds the Docker image
2. Runs **Trivy** vulnerability scan — pipeline fails if CRITICAL CVEs are found
3. Tags image with commit SHA
4. Pushes to ECR
5. Updates the Kubernetes manifest with the new image tag
6. Argo CD detects the manifest change and deploys to EKS automatically

---

## (d) Kubernetes Deployment (4 Marks)

### Zero-Downtime Deployments

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 0   # Never kill old pod before new one is ready
    maxSurge: 1         # Spin up 1 extra pod during the update
```

Combined with a **readiness probe** on `/api/health` — Kubernetes only sends traffic to a pod after it passes the health check. Without this, Kubernetes might route traffic to a pod that's still booting, causing errors during deployments.

### Autoscaling — HPA vs VPA

We use **HPA (Horizontal Pod Autoscaler)**:

```yaml
minReplicas: 2
maxReplicas: 10
metrics:
  - cpu: averageUtilization 60%
  - memory: averageUtilization 70%
```

**Why HPA and not VPA?**  
VPA (Vertical Pod Autoscaler) resizes pods by **restarting them** — which causes downtime. HPA adds more pod replicas **without restarting anything**. For a live API that needs zero downtime, HPA is the correct choice.

We use 60% CPU threshold (not 80%) to give headroom — at 80%, new pods take ~30 seconds to start, during which requests pile up and users see errors.

**Minimum 2 replicas** ensures the app survives a single node failure — one pod per Availability Zone.

### Secrets Management

DB credentials are **not** in the Deployment YAML or in Git. Instead:

1. Credentials are stored in **AWS Secrets Manager**
2. The **AWS Secrets Store CSI Driver** mounts them into pods at runtime as environment variables
3. A Kubernetes `ServiceAccount` with an **IAM Role (IRSA)** allows only the backend pods to access those secrets — frontend pods cannot

This means secrets never appear in Git, never appear in Kubernetes etcd in plaintext, and are automatically updated when rotated in AWS Secrets Manager.

### Inter-Service Communication

- Frontend → Backend: Via Kubernetes `ClusterIP` Service (`http://backend-service:3000`). Pods never communicate via IP addresses — service names are stable even when pods restart
- Backend → RDS: Via RDS DNS endpoint, credentials from Secrets Manager
- **Kubernetes Network Policies** restrict this strictly:
  - Frontend pods can only egress to backend-service on port 3000
  - Backend pods can only egress to RDS on port 5432
  - No arbitrary cross-pod communication is allowed

### GitOps with Argo CD

Argo CD watches this Git repository. When GitHub Actions pushes a new image tag to `k8s/backend-deployment.yaml`, Argo CD detects the change within 3 minutes and automatically applies the rolling update to the EKS cluster.

If the deployment fails (readiness probe never passes within 5 minutes), Argo CD marks the sync as `Degraded` and stops — the old pods keep running. The engineer is alerted and can roll back with:

```bash
argocd app rollback fintech-backend
```

---

## (e) CI/CD Pipeline Design (3 Marks)

### Pipeline Stages
Push to main
│
▼
[1] Lint & Test
│  npm test, eslint
│  Fails here = no image built
▼
[2] Build Docker Images
│  docker build for backend + frontend
▼
[3] Security Scan (Trivy)
│  Fails on CRITICAL CVEs = image not pushed
▼
[4] Push to ECR
│  Tagged with commit SHA
▼
[5] Update K8s Manifest
│  Image tag updated in k8s/ yaml files
│  Committed back to repo
▼
[6] Argo CD Auto-Sync
│  Detects manifest change
│  Applies rolling update to EKS
▼
[7] Rollout Health Check
Argo CD monitors — alerts on Slack if Degraded
### Trigger Mechanisms

| Trigger | Action |
|---|---|
| Push to `main` | Full pipeline → deploy to staging |
| Push to `release/*` | Full pipeline → deploy to prod |
| Pull Request | Lint + Test only, no build or push |
| Manual dispatch | Deploy a specific image tag to any environment |

### Rollback Strategy

**Automatic:** If the Kubernetes rolling update fails, Kubernetes automatically rolls back to the previous ReplicaSet. No human action needed.

**Manual:** Every image is tagged with a Git commit SHA, so rollback is always possible:
```bash
# Option 1 - Argo CD rollback
argocd app rollback fintech-backend

# Option 2 - Git revert (Argo CD auto-deploys the reverted tag)
git revert <commit-sha>
git push
```

---

## (f) Failure & Failover Scenario (2 Marks)

**Scenario:** The primary AWS region (us-east-1) becomes unavailable. Traffic must be routed to the secondary region (us-west-2) with minimal downtime.

### Traffic Failover

Route 53 is configured with:
- **Primary record:** ALB in us-east-1 with a health check hitting `/api/health` every 10 seconds
- **Secondary record (Failover routing policy):** ALB in us-west-2, only activated when the primary health check fails

When us-east-1 goes down:
1. Route 53 health check fails 3 consecutive times (~30 seconds)
2. Route 53 automatically updates DNS to point to the us-west-2 ALB
3. New connections go to the secondary region
4. Total failover time: **~1-2 minutes** (DNS TTL set to 60 seconds)

### Data Consistency

- RDS in us-east-1 is the primary with an **async read replica** in us-west-2
- **RPO (Recovery Point Objective): ~30 seconds** — transactions in the last 30 seconds before failure may be lost due to async replication lag
- During failover: a **CloudWatch Alarm** detects the primary going down → triggers a **Lambda function** → calls `rds promote-read-replica` API → us-west-2 replica becomes the new primary (~1-3 minutes)
- The backend in us-west-2 is updated with the new RDS endpoint automatically via Secrets Manager

**Why async and not synchronous replication?**  
Synchronous cross-region replication adds ~50-100ms latency to every single write (round-trip to us-west-2 before confirming the transaction). We accept a ~30 second RPO to avoid adding 100ms to every API response. For a fintech app handling hundreds of requests per second, that latency cost is not acceptable.

### Tools Used

| Tool | Role |
|---|---|
| AWS Route 53 | DNS-based failover routing with health checks |
| AWS CloudWatch | Monitors primary region health, triggers Lambda |
| AWS Lambda | Automates RDS read replica promotion |
| AWS RDS Read Replica | Cross-region async data replication |
| Argo CD | Re-deploys app in secondary region from same Git source |

---

*CSET 452 DevOps Assignment*
