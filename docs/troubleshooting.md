# Troubleshooting Guide

Real gotchas we hit while building this. Each one cost 15-30 minutes to debug.

---

## Gotcha 1: Frontend Can't Install Nginx

**Symptom:** Startup script fails. `apt-get update` hangs or errors with "Cannot initiate the connection to deb.debian.org."

**Error log:**
```
Cannot initiate the connection to deb.debian.org:443
E: Failed to fetch https://deb.debian.org/debian/pool/main/n/nginx/...
```

**Root cause:** The frontend instances are in a "public" subnet but have **no external IP** — traffic reaches them through the load balancer, not directly. Without an external IP, they can't reach the internet to download packages.

**Fix:** Add the public subnet to Cloud NAT alongside the private subnet:

```hcl
resource "google_compute_router_nat" "nat" {
  # ...
  subnetwork {
    name = google_compute_subnetwork.public.id    # <-- this was missing
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
  subnetwork {
    name = google_compute_subnetwork.private.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}
```

**Lesson:** "Public subnet" does NOT mean "has internet access." It means the subnet *could* have public-facing resources. If instances don't have external IPs (because traffic comes through a load balancer), they still need Cloud NAT for outbound connections.

---

## Gotcha 2: Cloud Armor Quota = 0 on Free Trial

**Symptom:** `terraform apply` fails with:

```
Error: Quota 'SECURITY_POLICIES' exceeded. Limit: 0.0 globally.
```

**Root cause:** Free trial GCP projects have a default quota of **zero** security policies. Cloud Armor requires a paid billing account or a quota increase request.

**Fix:** Comment out the `google_compute_security_policy` resource and remove `security_policy` references from backend services. Re-enable when you upgrade to a paid account.

**Lesson:** Not all GCP services are available on free trial. Cloud Armor, some GPU types, and certain networking features have zero-quota defaults. Always check quotas before including a service in your Terraform config: `gcloud compute project-info describe --project=YOUR_PROJECT | grep -A2 SECURITY`.

---

## Gotcha 3: Partial Apply — Cloud SQL Created But Not in State

**Symptom:** First `terraform apply` fails partway (e.g., due to Gotcha #2). Second `terraform apply` fails with:

```
Error: googleapi: Error 409: The Cloud SQL instance already exists., instanceAlreadyExists
```

**Root cause:** Terraform created the Cloud SQL instance on the first run, then crashed before saving it to the state file. On retry, it tries to create it again but GCP says "already exists."

**Fix:** Import the existing resource into Terraform state:

```bash
terraform import \
  'module.database.google_sql_database_instance.main' \
  'projects/YOUR_PROJECT/instances/landing-zone-db-demo'
```

Then re-run `terraform apply`. It will recognize the existing instance and only create what's missing.

**Lesson:** Terraform is more resilient than you think. Partial failures are normal — especially on first deploys with API propagation delays. `terraform import` is your friend. The state file is the source of truth, and you can always reconcile it with reality.

---

## Gotcha 4: API Not Enabled Yet

**Symptom:** First `terraform apply` enables APIs (e.g., Compute Engine) and immediately tries to use them. Fails with:

```
Error 403: Compute Engine API has not been used in project ... before or it is disabled.
```

**Root cause:** API enablement is asynchronous. Terraform enables the API and immediately tries to create resources, but GCP hasn't fully propagated the change yet.

**Fix:** Just run `terraform apply` again. The API will be ready by then. This is a one-time issue on first deploy.

**Lesson:** Use `depends_on = [google_project_service.apis]` in your modules (we do this), but know that it doesn't guarantee the API is *fully propagated* — just that the enable request was sent. A retry solves it.

---

## Gotcha 5: Load Balancer Returns 502

**Symptom:** After `terraform apply` succeeds, visiting the LB IP returns "502 Bad Gateway" or "unconditional drop overload."

**Root cause:** The LB health checks haven't marked instances as healthy yet. Instances need to boot, run startup scripts (install packages, start services), and pass 2 consecutive health checks.

**Fix:** Wait 5-10 minutes. Check health status:

```bash
gcloud compute backend-services get-health frontend-backend-svc-demo --global
gcloud compute backend-services get-health backend-backend-svc-demo --global
```

If instances stay `UNHEALTHY`, SSH in and check the startup script:

```bash
gcloud compute ssh INSTANCE_NAME --zone=ZONE --tunnel-through-iap \
  --command="sudo journalctl -u google-startup-scripts.service --no-pager | tail -20"
```

**Lesson:** LB health checks are separate from MIG auto-healing health checks. Both need to pass. Set `initial_delay_sec` high enough for your startup script to finish (we use 120s for frontend, 180s for backend).

---

## Quick Diagnostic Commands

```bash
# Check instance health from LB perspective
gcloud compute backend-services get-health frontend-backend-svc-demo --global
gcloud compute backend-services get-health backend-backend-svc-demo --global

# Check MIG instance status
gcloud compute instance-groups managed list-instances frontend-mig-demo --region=REGION
gcloud compute instance-groups managed list-instances backend-mig-demo --region=REGION

# SSH into an instance (no public IP needed — uses IAP)
gcloud compute ssh INSTANCE_NAME --zone=ZONE --tunnel-through-iap

# Check startup script logs
sudo journalctl -u google-startup-scripts.service --no-pager

# Check if nginx is running (frontend)
systemctl status nginx

# Check if backend is running
systemctl status backend
curl localhost:8080/health

# Check Cloud SQL connectivity from backend
nc -zv CLOUD_SQL_PRIVATE_IP 5432

# Check NAT is working (from any instance)
curl -s https://ifconfig.me

# Nuclear option: check what Terraform thinks exists
terraform state list
terraform state show MODULE.RESOURCE
```
