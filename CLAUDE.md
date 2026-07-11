# CLAUDE.md — GCP Landing Zone

## Overview

Terraform project that provisions a production-grade 3-tier application on Google Cloud. 54 resources across 7 modules: networking, IAM, secrets, database, storage, compute, and load balancing. Portfolio/resume piece demonstrating IaC and enterprise landing zone patterns.

The "application" is a placeholder (nginx frontend + Flask API backend + PostgreSQL). The value is the infrastructure, not the app.

## Tech stack

| Tool | Version |
|------|---------|
| Terraform | >= 1.5 |
| Google Provider | >= 5.0 |
| Shell (bash) | setup.sh interactive installer |
| GCP region | asia-east1 (default) |

## Key commands

```bash
# Interactive setup (recommended for first deploy)
./setup.sh

# Manual workflow
cp terraform.tfvars.example terraform.tfvars   # edit with your values
terraform init
terraform plan
terraform apply

# Day-to-day
terraform output                    # LB IP, SQL connection, bucket URL
terraform plan                      # preview changes
terraform fmt                       # format all .tf files
terraform validate                  # syntax + type check

# Teardown (STOP BILLING)
terraform destroy

# SSH via IAP (no public IP needed)
gcloud compute ssh INSTANCE_NAME --zone=ZONE --tunnel-through-iap

# Health checks
gcloud compute backend-services get-health frontend-backend-svc-demo --global
gcloud compute backend-services get-health backend-backend-svc-demo --global
```

## Architecture

```
Internet → Cloud Armor (WAF, disabled by default) → Global HTTPS LB + Cloud CDN
  ├── Frontend MIG (GCE, nginx, public subnet, autoscale 1-3)
  └── Backend MIG (GCE, Flask, private subnet, autoscale 1-3)
        ├── Cloud SQL PostgreSQL 15 (private IP via VPC peering)
        └── Cloud Storage (static assets)

Networking: VPC with public/private subnets, Cloud NAT for outbound
Secrets: DB password in Secret Manager
IAM: dedicated service account per tier (least-privilege)
```

## Modules

| Module | Path | Provisions |
|--------|------|------------|
| `network` | `modules/network/` | VPC, public/private subnets, firewall rules, Cloud Router, Cloud NAT, Private Services Access |
| `iam` | `modules/iam/` | 3 service accounts (frontend, backend, sql-proxy) + role bindings |
| `secrets` | `modules/secrets/` | Secret Manager entry for DB password + access bindings |
| `database` | `modules/database/` | Cloud SQL PostgreSQL, private IP, automated backup |
| `storage` | `modules/storage/` | GCS bucket + IAM bindings |
| `compute` | `modules/compute/` | Instance templates (FE/BE), MIGs, health checks, autoscalers, startup scripts |
| `load-balancer` | `modules/load-balancer/` | Global LB, backend services, URL map, Cloud CDN, Cloud Armor (commented out) |

## Key files

| File | Purpose |
|------|---------|
| `main.tf` | Root module — enables APIs, wires all 7 modules together |
| `variables.tf` | Input variables (project_id, region, machine types, scaling, db_password) |
| `outputs.tf` | LB IP, SQL connection name, SQL private IP, bucket URL, SA emails |
| `setup.sh` | Interactive bash installer — prereq check, config interview, generates tfvars, deploys |
| `terraform.tfvars.example` | Example variable values to copy |
| `providers.tf` | Google provider config |
| `versions.tf` | Terraform + provider version constraints |
| `modules/compute/startup-fe.sh` | Frontend startup script (nginx install) |
| `modules/compute/startup-be.sh` | Backend startup script (Flask app) |
| `SPEC.md` | Full project specification + implementation plan |
| `docs/architecture.md` | Design decisions |
| `docs/troubleshooting.md` | Real gotchas with fixes |

## Key variables

```hcl
project_id             # Required — GCP project ID
db_password            # Required — sensitive, stored in Secret Manager
region                 # Default: asia-east1
zone                   # Default: asia-east1-b
environment            # Default: demo
frontend_machine_type  # Default: e2-micro
backend_machine_type   # Default: e2-micro
use_preemptible        # Default: true (70% cheaper)
db_tier                # Default: db-g1-small
```

## Cost

~$3-5/day when running. $0 when destroyed. Always `terraform destroy` when not actively working.

Cloud SQL takes ~5 minutes to delete — `terraform destroy` will look stuck. Just wait.

## Known issues

1. **terraform.tfstate files on disk** — `terraform.tfstate`, `terraform.tfstate.backup`, and `terraform.tfstate.1773098738.backup` exist in the project directory. The `.gitignore` excludes `*.tfstate` and `*.tfstate.backup`, so they should not be committed. However, for any team or production use, state should be stored in a remote backend (GCS bucket with state locking). Local state is a single point of failure and cannot be shared across machines.

2. **Cloud Armor disabled** — WAF security policy is commented out because free trial GCP projects have zero quota for security policies. Uncomment when using a paid billing account.

3. **No remote backend configured** — Terraform state is local-only. Production setup should use a GCS backend with state locking:
   ```hcl
   terraform {
     backend "gcs" {
       bucket = "your-tf-state-bucket"
       prefix = "landing-zone"
     }
   }
   ```

4. **Single environment** — No dev/staging/prod separation. This is intentional for v1 (portfolio demo).

5. **LB health check delay** — After deploy, the load balancer returns 502 for 5-10 minutes while health checks converge. This is normal GCP behavior, not a bug.

## Conventions

- Naming pattern: `{resource}-{environment}` (e.g., `frontend-demo`, `landing-zone-vpc-demo`)

## Learned Rules

_(None yet — add entries here when gotchas are discovered during development.)_

```
### Rule N: [Short title]
- **Trigger**: What happened / what went wrong
- **Correct behavior**: What should have been done
- **Date**: YYYY-MM-DD
```
