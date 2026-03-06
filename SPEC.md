# GCP Landing Zone — 3-Tier App with Terraform

> Resume project: demonstrate IaC skills on production-grade GCP architecture.

---

## Why This Project

Jazz has 6 GCP Professional certifications but zero IaC on the resume. Enterprise cloud roles expect Terraform fluency. This project bridges that gap with a real, deployable architecture — not a toy tutorial.

**Goal:** Build a Terraform codebase that provisions a complete GCP 3-tier application following landing zone best practices. Use it as a portfolio piece and write a blog post about it.

**Non-goals:**
- Not building an actual application (the app is a placeholder — nginx + a simple API)
- Not multi-environment (dev/staging/prod) — single environment is fine for v1
- Not a reusable Terraform module library — just one clean, working stack
- Not production traffic — this is a demo, keep costs near zero

---

## Architecture

```
                    Internet
                       |
                  Cloud Armor (WAF)
                       |
                Global HTTPS Load Balancer
                  + Cloud CDN (static cache)
                       |
              +--------+--------+
              |                 |
        Frontend MIG       Backend MIG
        (GCE, nginx)       (GCE, API server)
        Public subnet      Private subnet
              |                 |
              |        +--------+--------+
              |        |                 |
              |   Cloud SQL          Cloud Storage
              |   (PostgreSQL)       (static assets)
              |   Private IP only    IAM-controlled
              |        |
              +--------+
              via Internal LB or
              direct private network
                       |
                  Cloud NAT
               (outbound only)
```

### GCP Services Used

| Layer | Service | Purpose |
|-------|---------|---------|
| Edge | Cloud CDN | Cache static content at edge |
| Security | Cloud Armor | WAF rules, DDoS protection |
| Load Balancing | Global HTTPS LB | SSL termination, routing |
| Compute (FE) | GCE + Managed Instance Group | nginx serving frontend |
| Compute (BE) | GCE + Managed Instance Group | API server (Python/Node placeholder) |
| Database | Cloud SQL (PostgreSQL) | Private IP, automated backups |
| Storage | Cloud Storage | Static assets, uploads |
| Networking | VPC, subnets, Cloud NAT, Cloud Router | Network isolation |
| Secrets | Secret Manager | DB credentials, API keys |
| IAM | Service Accounts | Least-privilege per tier |
| Logging | Cloud Logging + Monitoring | Observability baseline |

---

## Terraform Module Structure

```
gcp-landing-zone/
+-- SPEC.md                  # This file
+-- CLAUDE.md                # Dev guidance: Terraform conventions, common gotchas, learned rules
+-- README.md                # Setup instructions + architecture diagram
+-- main.tf                  # Root module, orchestrates everything
+-- variables.tf             # Input variables (project_id, region, etc.)
+-- outputs.tf               # LB IP, SQL connection, bucket URL
+-- terraform.tfvars.example # Example variable values
+-- providers.tf             # Google provider config
+-- versions.tf              # Terraform + provider version constraints
+--
+-- modules/
|   +-- network/             # VPC, subnets, firewall, Cloud NAT, Cloud Router
|   |   +-- main.tf
|   |   +-- variables.tf
|   |   +-- outputs.tf
|   |
|   +-- compute/             # GCE instances, instance templates, MIGs
|   |   +-- main.tf          # Frontend + Backend instance groups
|   |   +-- variables.tf
|   |   +-- outputs.tf
|   |   +-- startup-fe.sh    # Frontend startup script (install nginx)
|   |   +-- startup-be.sh    # Backend startup script (install app)
|   |
|   +-- load-balancer/       # Global HTTPS LB + Cloud CDN + Cloud Armor WAF
|   |   +-- main.tf          # LB + CDN config + Cloud Armor policy (attached to backend service)
|   |   +-- variables.tf
|   |   +-- outputs.tf
|   |
|   +-- database/            # Cloud SQL instance, private IP, users
|   |   +-- main.tf
|   |   +-- variables.tf
|   |   +-- outputs.tf
|   |
|   +-- storage/             # GCS bucket + IAM
|   |   +-- main.tf
|   |   +-- variables.tf
|   |   +-- outputs.tf
|   |
|   +-- iam/                 # Service accounts + role bindings
|   |   +-- main.tf
|   |   +-- variables.tf
|   |   +-- outputs.tf
|   |
|   +-- secrets/             # Secret Manager entries + access bindings
|       +-- main.tf
|       +-- variables.tf
|       +-- outputs.tf
+--
+-- docs/
    +-- architecture.md      # Detailed design decisions
    +-- blog-draft.md        # Blog post draft
```

---

## Landing Zone Best Practices Covered

These are the enterprise patterns this project demonstrates:

1. **Network Isolation** — Public subnet (frontend) vs private subnet (backend + DB). Backend has no public IP.
2. **Private Services Access for Cloud SQL** — Cloud SQL connected via `google_service_networking_connection` + `google_compute_global_address` (private IP range allocation). This is the part most people get wrong — it requires VPC peering to Google's service producer network, not just "private IP = done."
3. **Least-Privilege IAM** — Dedicated service account per tier. No default compute SA. Only the permissions each tier actually needs.
4. **Workload Identity awareness** — v1 uses scoped SA keys (Secret Manager access only). Workload Identity Federation is out of scope for v1 but noted as the production-grade approach. No SA key files downloaded or committed — secrets accessed via instance metadata + Secret Manager API.
5. **Secrets Management** — DB password in Secret Manager, not in tfvars or env vars. Backend reads secret at runtime via SA permission.
6. **Defense in Depth** — Cloud Armor WAF on LB. Firewall rules restrict traffic between tiers. Cloud SQL only accessible from backend subnet.
7. **Outbound Control** — Cloud NAT for backend instances that need internet (package installs) without public IPs.
8. **Org Policy Constraints** — Document constraints like `constraints/compute.vmExternalIpAccess` (restrict external IPs to frontend only) and `constraints/sql.restrictPublicIp` (block public Cloud SQL) in `docs/architecture.md`. Note: these require an Organization node — personal GCP projects don't have one. Document with a note: "In an enterprise org, these would be enforced at the folder level." Don't try to `gcloud org-policies set` on a personal project — it will fail silently or error.
9. **Observability** — Cloud Logging agent on instances. Uptime checks on LB endpoint.
10. **Cost Control** — Small instance types (e2-micro/small). Preemptible option in variables. MIG autoscaling 1-3 instances.

---

## Implementation Plan

### Phase 1: Foundation (Day 1)
- [ ] Set up Terraform project structure + providers
- [ ] `network/` module: VPC, 2 subnets (public/private), firewall rules, Cloud Router, Cloud NAT
- [ ] `iam/` module: 3 service accounts (frontend, backend, sql-proxy)
- [ ] Validate: `terraform plan` succeeds

### Phase 2: Compute + Storage (Day 2)
- [ ] `compute/` module: Instance templates (FE + BE), MIGs, health checks
- [ ] `storage/` module: GCS bucket with IAM bindings
- [ ] Startup scripts: nginx (FE), simple Python HTTP server (BE)
- [ ] Validate: instances boot and serve HTTP

### Phase 3: Database + Secrets (Day 3)
- [ ] `database/` module: Cloud SQL PostgreSQL, private IP, automated backup
- [ ] `secrets/` module: Secret Manager for DB credentials
- [ ] Wire backend startup to read secret + connect to Cloud SQL
- [ ] Validate: backend can query DB

### Phase 4: Load Balancer + CDN + WAF (Day 4)
- [ ] `load-balancer/` module: Global HTTPS LB, backend services, URL map
- [ ] Cloud CDN on frontend backend service
- [ ] Cloud Armor security policy (attached to LB backend service — rate limiting, geo-blocking rules)
- [ ] SSL certificate (managed or self-signed for demo)
- [ ] Validate: access app via LB IP, CDN headers present

### Phase 5: Polish + Blog (Day 5)
- [ ] README with architecture diagram, setup instructions, and prominent `terraform.tfvars.example` section (this is the #1 friction point for anyone cloning the repo — make it impossible to miss)
- [ ] CLAUDE.md with: Terraform naming conventions used, `terraform fmt` / `terraform validate` as pre-commit habits, common gotchas encountered, learned rules
- [ ] `terraform destroy` confirms clean teardown (cost safety)
- [ ] Document design decisions in `docs/architecture.md`
- [ ] Draft blog post in `docs/blog-draft.md`
- [ ] Record total GCP cost: add an "Actual vs Estimated Cost" table in the blog post (estimate from spec vs real billing after running for a day). Readers love this — takes 2 minutes, makes the post significantly more shareable

---

## Cost Estimate

Target: under $5/day while testing, $0 when destroyed.

| Resource | Spec | Est. Cost |
|----------|------|-----------|
| GCE (2x FE + 2x BE) | e2-micro, preemptible | ~$1.20/day |
| Cloud SQL | db-g1-small, no HA | ~$1.00/day |
| Cloud LB | Forwarding rule | ~$0.60/day |
| Cloud NAT | Per gateway | ~$0.30/day |
| GCS | Minimal storage | ~$0.01/day |
| Cloud Armor | Basic policy | Free tier |
| **Total** | | **~$3.10/day** |

Always `terraform destroy` when not actively working.

---

## Success Criteria

1. `./setup.sh` walks any user from zero to deployed with an interactive interview
2. App is accessible via HTTPS load balancer IP
3. Frontend (nginx) serves static page, backend API returns data from Cloud SQL
4. `terraform destroy` tears down everything cleanly
5. Blog post published explaining the architecture + lessons learned
6. README is clear enough that another engineer could clone and deploy

---

## Tech Stack

| Tool | Version |
|------|---------|
| Terraform | >= 1.5 |
| Google Provider | >= 5.0 |
| GCP Project | Existing (Jazz's personal project) |
| Region | asia-east1 (Taiwan) |
| App placeholder | nginx (FE) + Python Flask (BE) + PostgreSQL |

---

## Blog Post Angle

**Title idea:** "I Have 6 GCP Certs But Never Wrote Terraform — Here's My First Landing Zone"

**Story arc:**
1. Why IaC matters even if you know the console inside out
2. Landing zone concepts: what enterprises actually care about
3. Walk through the architecture (with diagram)
4. **The "I thought this would be easy" moment** — pick ONE thing that humbled you during implementation. Candidates:
   - Cloud SQL Private Services Access (VPC peering to Google's service producer network, IP range allocation, the `google_service_networking_connection` dance)
   - MIG health check timing (instances marked unhealthy before app finishes booting)
   - Terraform dependency ordering (destroy fails because resources depend on each other in unexpected ways)
   - LB setup verbosity (backend service -> URL map -> target proxy -> forwarding rule -> managed cert — 5 resources for one endpoint)
   - **Document whichever one actually bites you. Don't pick in advance — let reality choose.**
5. The full Terraform code (link to GitHub repo)

**Target audience:** Cloud engineers who know GCP but haven't done IaC yet — basically, people like Jazz 6 months ago.

**What makes this post memorable:** Not the architecture diagram (everyone has one). It's the honest "I have 6 Professional certs and this still tripped me up" moment. That's what people share.
