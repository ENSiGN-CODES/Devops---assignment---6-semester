# Part (a): AWS Architecture Design [4 Marks]

## VPC Structure

The VPC uses CIDR `10.0.0.0/16` spread across **two Availability Zones** (ap-south-1a and ap-south-1b) with three tiers of subnets:

```
VPC: 10.0.0.0/16
│
├── Public Subnets (AZ1: 10.0.1.0/24, AZ2: 10.0.2.0/24)
│   └── ALB (Application Load Balancer) — internet-facing
│   └── NAT Gateways (one per AZ for HA egress)
│
├── Private App Subnets (AZ1: 10.0.3.0/24, AZ2: 10.0.4.0/24)
│   └── EKS Worker Nodes — no direct internet access
│   └── Backend and Frontend pods
│
└── Private DB Subnets (AZ1: 10.0.5.0/24, AZ2: 10.0.6.0/24)
    └── RDS PostgreSQL (Multi-AZ — primary in AZ1, standby in AZ2)
    └── ElastiCache Redis (primary + replica across AZs)
```

**Justification:** Three tiers enforce a security-first posture. The database tier is the most sensitive and has no route to the internet at all. EKS nodes in the app tier can only receive traffic from the ALB. One NAT Gateway per AZ (rather than sharing one) eliminates a single point of failure for outbound traffic, at a moderate cost increase.

## Service Placement

| Service | Placement | Why |
|---------|-----------|-----|
| ALB | Public subnets | Must accept internet traffic |
| EKS Control Plane | AWS Managed | No exposure in VPC |
| EKS Worker Nodes | Private App Subnets | Pods not directly reachable from internet |
| RDS PostgreSQL | Private DB Subnets | Database must never be internet-accessible |
| ElastiCache Redis | Private DB Subnets | Same isolation as RDS |

## Load Balancing

The AWS ALB (Application Load Balancer) is deployed in public subnets. The **AWS Load Balancer Controller** running in EKS manages the ALB based on Kubernetes Ingress resources. Path-based routing sends `/api/*` to backend pods and `/` to frontend pods. The ALB performs health checks every 30 seconds, removing unhealthy pods from rotation automatically.

## Multi-Region Design (Active-Passive)

An **active-passive** design is chosen over active-active to control cost:

- **Primary region:** ap-south-1 (Mumbai) — handles 100% of live traffic
- **Secondary region:** ap-southeast-1 (Singapore) — warm standby, receives no traffic unless primary fails

The secondary region has an identical VPC and EKS cluster provisioned via Terraform provider aliases. RDS has a **cross-region read replica** in Singapore that is promoted to primary during failover.

**Route 53** with a **failover routing policy** monitors the ALB health check endpoint. If the primary ALB returns unhealthy three times in a row (configurable), DNS automatically switches the domain to the secondary ALB.

## Trade-offs

| Decision | Trade-off |
|----------|-----------|
| Active-passive vs active-active | Active-passive costs ~40% less because the secondary region runs smaller instances. Active-active gives zero RPO but doubles infra cost. |
| Multi-AZ RDS | Doubles RDS cost but gives <30 second automatic failover — mandatory for fintech |
| One NAT per AZ | 2× NAT cost but eliminates cross-AZ traffic charges and AZ-level failure risk |

---

# Part (b): Terraform Strategy [4 Marks]

## Module Design

All infrastructure is broken into 4 focused modules:

```
modules/
├── vpc/    → VPC, subnets, IGW, NAT, route tables, subnet groups
├── eks/    → EKS cluster, managed node groups, IAM roles, add-ons
├── rds/    → RDS instance, parameter group, subnet group, security group, Secrets Manager
└── redis/  → ElastiCache replication group, parameter group, security group
```

Each module has exactly three files (`main.tf`, `variables.tf`, `outputs.tf`). The root `main.tf` wires modules together using outputs as inputs (e.g., VPC outputs the `vpc_id` which EKS, RDS, and Redis all consume).

## Remote State Management

State is stored in **S3 with DynamoDB locking** (`backend.tf`):

- **S3 bucket:** Versioned, encrypted, private — stores `terraform.tfstate`
- **DynamoDB table:** `LockID` attribute — prevents two engineers from running `terraform apply` simultaneously
- **Key structure:** `prod/terraform.tfstate` — environment-namespaced

This means if a `terraform apply` crashes mid-run, the state lock prevents a second apply from corrupting the state file.

## Environment Separation

Environments are separated using **folder-based isolation** rather than workspaces, because workspaces share the same backend bucket and are harder to manage access control on:

```
terraform/
├── envs/dev/        → terraform.tfvars with smaller instances (t3.small)
├── envs/staging/    → terraform.tfvars with medium instances
└── envs/prod/       → terraform.tfvars with production-grade instances
```

Each environment directory has its own `backend.tf` pointing to a different state key (`dev/terraform.tfstate`, `staging/terraform.tfstate`, `prod/terraform.tfstate`).

## Multi-Region Infrastructure Provisioning

The `provider.tf` defines two provider instances — a primary and a secondary with an **alias**:

```hcl
provider "aws" { region = var.aws_region }
provider "aws" { alias = "secondary"; region = var.secondary_region }
```

Resources for the secondary region pass `provider = aws.secondary`. Each region has its own separate remote state key so state operations do not conflict. Terraform can plan and apply both regions in the same run.

## Dependency Handling

Terraform's implicit dependency graph automatically resolves order: VPC must exist before EKS, RDS, or Redis can be created (all need `vpc_id`). Explicit `depends_on` is only used when there is no attribute-level reference.

## Challenges Addressed

- **State drift:** Terraform's `plan` command detects manual changes. A scheduled GitHub Actions job runs `terraform plan` nightly and alerts if drift is detected.
- **Region sync:** Each region has an independent state file. A shared root module applies to both using provider aliases. Cross-region data sources (like RDS read replica) explicitly reference the primary region state via `terraform_remote_state`.

---

# Part (c): Docker & Image Strategy [3 Marks]

## Dockerfile Optimization

Both Dockerfiles use **multi-stage builds**:

1. **Builder stage:** Full base image with build tools (gcc, npm) — used only at build time
2. **Runner stage:** Slim/Alpine base — only runtime dependencies copied in

Result: Backend image ~180MB instead of ~1.2GB. Frontend image ~25MB (nginx:alpine) instead of ~1GB (node).

## Security Hardening

- **Non-root user:** Both Dockerfiles create a dedicated system user (`appuser`, `nginxuser`) and switch to it before the `CMD`
- **Minimal packages:** Only runtime libraries installed in final stage (no compilers, no dev tools)
- **No secrets in images:** Environment variables are injected at runtime via Kubernetes Secrets, never baked into the image
- **Vulnerability scanning:** Trivy scans every image in the CI pipeline before push; `CRITICAL` severity fails the build

## CI/CD Integration

Images are tagged with the **git commit SHA** (first 8 characters) at build time:

```
fintech-backend:a1b2c3d4
fintech-backend:latest
```

The commit SHA tag provides full traceability — you can always identify exactly which code version is running. The `latest` tag is also updated so the default deployment always has something to pull. After push, the CI pipeline updates the Kubernetes deployment YAML with the new SHA tag and commits it, triggering Argo CD.

---

# Part (d): Kubernetes Deployment [4 Marks]

## Zero-Downtime Deployments

Two mechanisms work together:

1. **RollingUpdate strategy:** `maxUnavailable: 1, maxSurge: 1` — at most one pod is taken down at a time, and one extra pod is added first
2. **readinessProbe:** A pod only receives traffic after the `/health` endpoint returns HTTP 200. During a rolling update, the new pod must pass readiness before the old pod is terminated. This is the key mechanism that prevents downtime.

## Autoscaling — HPA

The **Horizontal Pod Autoscaler (HPA)** is configured on the backend deployment:

- Minimum replicas: 3 (HA baseline)
- Maximum replicas: 10
- Scale-up trigger: CPU utilization > 70% averaged across all pods
- Scale-up trigger: Memory utilization > 80%
- Scale-up stabilization: 60 seconds (prevents thrashing)
- Scale-down stabilization: 300 seconds (avoids scaling down too aggressively during brief lulls)

**VPA (Vertical Pod Autoscaler) decision:** VPA is not used in production because it requires pod restarts to resize. For a fintech app requiring zero downtime, HPA horizontal scaling is preferred.

## Secrets Management

Kubernetes Secrets store DB credentials and Redis connection strings. In production, the **External Secrets Operator** is deployed (see `database/secret.yaml`). It syncs secrets directly from **AWS Secrets Manager** into Kubernetes Secrets on a 1-hour refresh cycle. This means:
- Credentials are never committed to Git
- Secret rotation in AWS Secrets Manager propagates automatically to running pods
- Audit trail of secret access is available in CloudWatch

## GitOps with Argo CD

Argo CD is configured via `argocd-application.yaml` to watch the `kubernetes/` folder in this repository. When GitHub Actions commits an updated image tag:

1. Argo CD detects the git diff within ~3 minutes (or immediately after manual sync)
2. Argo CD applies the changed manifests to EKS
3. Kubernetes performs the rolling update using the new image
4. Argo CD reports application health back in its UI

`selfHeal: true` means if anyone manually changes a Kubernetes resource (drift), Argo CD automatically reverts it to match Git — Git is always the source of truth.

---

# Part (e): CI/CD Pipeline Design [3 Marks]

## Pipeline Stages

```
PUSH TO MAIN
     │
     ▼
┌──────────────────────────────┐
│  STAGE 1: Build & Test       │  ← Runs on push AND pull requests
│  - docker build (backend)    │
│  - docker build (frontend)   │
│  - run pytest                │
│  - trivy vulnerability scan  │
└──────────────┬───────────────┘
               │ (only continues if push to main)
               ▼
┌──────────────────────────────┐
│  STAGE 2: Push to ECR        │
│  - aws ecr login             │
│  - tag with commit SHA       │
│  - push backend image        │
│  - push frontend image       │
└──────────────┬───────────────┘
               ▼
┌──────────────────────────────┐
│  STAGE 3: Update Manifests   │
│  - sed replace image tags    │
│  - git commit + push         │
│  (Argo CD sees this change)  │
└──────────────┬───────────────┘
               ▼
┌──────────────────────────────┐
│  STAGE 4: Sync Argo CD       │
│  - argocd app sync           │
│  - wait for healthy status   │
└──────────────────────────────┘
```

## Trigger Mechanisms

| Trigger | Effect |
|---------|--------|
| `push` to `main` | Full pipeline: build → test → push → deploy |
| `pull_request` to `main` | Stage 1 only: build + test (no deploy) |
| Manual `workflow_dispatch` | Rollback pipeline: roll back to any past tag |

## Failure Handling & Rollback

**Automatic failure handling:**
- Each stage has `needs:` dependency — if Stage 1 fails, Stages 2-4 never run, so bad code never reaches ECR or Kubernetes
- Trivy scan failure on `CRITICAL` severity blocks the pipeline before push
- `argocd app wait --health --timeout 300` — if Argo CD reports the app unhealthy after 5 minutes, the pipeline job fails and the team is notified

**Manual rollback:**
- The `rollback.yml` workflow is triggered manually via the GitHub Actions UI
- Engineer inputs the target image tag (e.g., `a1b2c3d4`) and a reason
- Pipeline validates the tag exists in ECR, then updates manifests and syncs Argo CD
- Also possible: `argocd app rollback fintech-app` from CLI to revert to previous Argo CD sync

---

# Part (f): Failure & Failover Scenario [2 Marks]

## Scenario: Primary Region (ap-south-1) Becomes Unavailable

### Traffic Failover

**Route 53 Failover Routing Policy** manages DNS:

1. Route 53 **health checks** ping the primary ALB endpoint (`/health`) every 30 seconds
2. After 3 consecutive failures (configurable), Route 53 marks the primary as unhealthy
3. Route 53 **automatically updates DNS** to point the domain to the secondary ALB in ap-southeast-1 (Singapore)
4. DNS TTL is set to **60 seconds** — within 1-2 minutes, new connections go to secondary region
5. Existing connections (TCP) are dropped and clients must reconnect — browsers retry automatically

**Total estimated failover time: 2–4 minutes** (health check detection + DNS propagation)

### Data Consistency

**RDS PostgreSQL:**
- The secondary region has a **cross-region read replica** continuously replicated from the primary
- During failover, the read replica is **promoted to a standalone primary** (AWS CLI: `aws rds promote-read-replica`)
- **Replication lag** is typically <1 second for small transactions, but any writes during the outage that had not yet replicated are lost (RPO ≈ seconds)
- After recovery, the original primary becomes the new replica to avoid data conflicts

**Redis (ElastiCache):**
- Redis is session/cache data — it is **not cross-region replicated** by default
- Users will experience cache misses after failover. The application handles this gracefully by falling through to the database
- A new Redis cluster in the secondary region serves fresh cache data

### Tools & Services Used

| Tool | Role |
|------|------|
| Route 53 | DNS failover with health checks |
| AWS RDS cross-region read replica | Data replication to secondary |
| Terraform provider aliases | Same IaC code provisions both regions |
| Argo CD (secondary cluster) | Kubernetes deployments in secondary region |
| CloudWatch + SNS | Alerts team when failover triggers |
