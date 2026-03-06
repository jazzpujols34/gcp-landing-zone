# Architecture Decisions

Why things are built the way they are. Not just "what" — the "why."

---

## Network: Private Services Access for Cloud SQL

Cloud SQL "private IP" sounds simple. It's not. Here's what actually happens:

1. **Allocate an IP range** — Reserve a `/16` CIDR block inside your VPC for Google's use
2. **Create a VPC peering connection** — Peer your VPC with Google's service producer network (`servicenetworking.googleapis.com`)
3. **Assign Cloud SQL to that range** — Set `private_network` in `ip_configuration`

```hcl
# Step 1: Reserve IP range
resource "google_compute_global_address" "private_services_range" {
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

# Step 2: Peer with Google's network
resource "google_service_networking_connection" "private_services" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services_range.name]
}

# Step 3: Cloud SQL uses the peered network
resource "google_sql_database_instance" "main" {
  depends_on = [google_service_networking_connection.private_services]
  settings {
    ip_configuration {
      ipv4_enabled    = false          # No public IP
      private_network = var.network_id  # Your VPC
    }
  }
}
```

This is **Private Services Access** (VPC peering). It's different from **Private Service Connect** (PSC), which uses forwarding rules and is newer. We chose Private Services Access because it's more mature and widely documented for Cloud SQL.

**Common mistake:** Setting `ipv4_enabled = false` without the VPC peering connection. Cloud SQL will fail to create because it has no network to attach to.

---

## Network: Why Both Subnets Need Cloud NAT

Our "public" subnet isn't really public. Instances don't have external IPs — traffic reaches them through the Global Load Balancer. This means:

- Instances can receive inbound traffic (via LB)
- Instances **cannot** make outbound connections (no external IP)
- Startup scripts that run `apt-get install` will fail silently

Solution: Cloud NAT covers both subnets. Every instance can reach the internet for package installs, API calls, etc.

**In a real enterprise**, you might want frontend instances to have no outbound access at all (pure static serving). In that case, use a custom image with nginx pre-installed instead of a startup script.

---

## IAM: Least-Privilege Per Tier

Each tier gets its own service account with only the permissions it needs:

| Service Account | Roles | Why |
|----------------|-------|-----|
| `sa-frontend-demo` | `logging.logWriter`, `monitoring.metricWriter` | Frontend only serves static files. No DB, no secrets, no storage. |
| `sa-backend-demo` | `logging.logWriter`, `monitoring.metricWriter`, `secretmanager.secretAccessor`, `cloudsql.client`, `storage.objectViewer` | Backend needs DB access, secret reading, and GCS for uploads. |

**What we intentionally avoided:**
- No `roles/editor` or `roles/owner` on any service account
- No default compute service account (it has `roles/editor` by default — too broad)
- Secret Manager access is granted at the **secret level**, not project level, in the `secrets/` module

**Workload Identity (not implemented in v1):** In production, you'd use Workload Identity Federation to avoid service account keys entirely. GCE instances authenticate via their attached service account metadata — no key files needed. Our v1 uses this implicitly (instance metadata + `scopes = ["cloud-platform"]`), which is better than downloaded key files but not as good as full WIF with external identity providers.

---

## Load Balancer: Why So Many Resources?

A single "load balancer" in GCP is actually 5-6 Terraform resources:

```
Global IP Address
    └── Global Forwarding Rule (port 80 → target proxy)
            └── Target HTTP Proxy (→ URL map)
                    └── URL Map (routing rules)
                            ├── Frontend Backend Service (/ → nginx MIG)
                            │       └── Health Check
                            └── Backend Backend Service (/api/* → Flask MIG)
                                    └── Health Check
```

This is verbose but each piece is independently configurable:
- **URL Map** routes `/api/*` to backend, everything else to frontend
- **Backend Services** have independent health checks, timeouts, and CDN settings
- **CDN** enabled only on the frontend backend service (static content)
- **Cloud Armor** attaches at the backend service level (commented out for free trial)

**HTTP vs HTTPS:** We use HTTP (port 80) for the demo because HTTPS requires either a domain name (for managed certificates) or a self-signed cert. In production, you'd add `google_compute_managed_ssl_certificate` and a `google_compute_target_https_proxy`.

---

## Health Checks: MIG vs LB

There are two separate sets of health checks:

| Health Check | Purpose | Location |
|-------------|---------|----------|
| MIG auto-healing | Replace crashed instances | `modules/compute/` |
| LB backend service | Route traffic to healthy instances | `modules/load-balancer/` |

They check the same endpoints but have different thresholds:
- **MIG health checks** have higher `initial_delay_sec` (120s frontend, 180s backend) to give startup scripts time to finish
- **LB health checks** have lower intervals (10s) for faster traffic failover

**Why separate?** A MIG health check failure triggers instance replacement (expensive, slow). An LB health check failure just stops routing traffic (fast, cheap). Different failure responses need different sensitivity.

---

## Cloud Armor: Commented Out

Cloud Armor (WAF) is commented out because free trial GCP projects have zero quota for security policies. The code is there and ready to uncomment when using a paid billing account.

What it would provide:
- Rate limiting (100 req/min per IP)
- Ban duration (5 min after exceeding limit)
- Extensible: add geo-blocking, OWASP rules, custom expressions

---

## Org Policy Constraints (Enterprise Context)

In a personal GCP project, there's no Organization node, so org policies don't apply. In an enterprise environment, these would be enforced at the folder or org level:

| Constraint | Effect |
|-----------|--------|
| `constraints/compute.vmExternalIpAccess` | Restrict which VMs can have external IPs (frontend only, or none) |
| `constraints/sql.restrictPublicIp` | Block Cloud SQL instances from having public IPs |
| `constraints/iam.disableServiceAccountKeyCreation` | Force Workload Identity instead of key files |
| `constraints/compute.requireShieldedVm` | Require Shielded VM for all instances |

These are documented here for awareness. If you're adapting this for an org, apply them at the folder level with `google_org_policy_policy`.

---

## Cost Decisions

| Decision | Saves | Trade-off |
|---------|-------|-----------|
| `e2-micro` instances | ~80% vs `e2-standard-2` | Slower startup, limited capacity |
| Preemptible/spot VMs | ~70% vs on-demand | May restart anytime (MIG recreates) |
| `db-g1-small` Cloud SQL | ~50% vs `db-custom-1-3840` | Shared vCPU, limited connections |
| No HA for Cloud SQL | ~50% vs regional | Single zone, no automatic failover |
| No HTTPS (HTTP only) | Free managed cert | Not production-ready |
| Cloud Armor disabled | Avoids quota issues | No WAF protection |

**Total estimated cost:** ~$3-5/day. Always `terraform destroy` when not testing.
