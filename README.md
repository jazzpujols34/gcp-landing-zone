# GCP Landing Zone — 3-Tier App with Terraform

Deploy a production-grade 3-tier application on GCP with a single command.

```
Cloud CDN → Global Load Balancer → GCE Frontend (nginx)
                                 → GCE Backend (Flask API) → Cloud SQL (PostgreSQL)
                                                            → Cloud Storage
```

## Quick Start

```bash
git clone <this-repo>
cd gcp-landing-zone
./setup.sh
```

The setup script will:
1. Check that Terraform and gcloud are installed
2. Ask you a few questions (project ID, region, instance sizes, DB password)
3. Generate `terraform.tfvars`
4. Run `terraform init` + `terraform plan` + `terraform apply`
5. Print the load balancer IP when done

**Total time:** ~15 minutes (most of it is GCP provisioning Cloud SQL).

## Prerequisites

- **Terraform** >= 1.5 ([install](https://developer.hashicorp.com/terraform/install))
- **gcloud CLI** authenticated ([install](https://cloud.google.com/sdk/docs/install))
- **GCP Project** with billing enabled
- **Permissions:** Owner or Editor on the project (for demo purposes)

```bash
# Authenticate
gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

## What Gets Deployed

| Layer | Service | Details |
|-------|---------|---------|
| Edge | Cloud CDN | Caches static content from frontend |
| Security | Cloud Armor | WAF with rate limiting (100 req/min/IP) |
| Load Balancing | Global HTTPS LB | Routes `/api/*` to backend, everything else to frontend |
| Frontend | GCE + MIG | nginx, autoscaling 1-3 instances |
| Backend | GCE + MIG | Flask API, autoscaling 1-3, private subnet |
| Database | Cloud SQL PostgreSQL 15 | Private IP only, daily backups |
| Storage | Cloud Storage | Static assets bucket |
| Networking | VPC + Cloud NAT | Public/private subnets, NAT for outbound |
| Secrets | Secret Manager | DB password stored securely |
| IAM | Service Accounts | Least-privilege per tier |

## Configuration

Copy the example and fill in your values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

```hcl
# terraform.tfvars
project_id  = "your-gcp-project-id"    # Required
region      = "asia-east1"              # Default: Taiwan
zone        = "asia-east1-b"
environment = "demo"

frontend_machine_type = "e2-micro"      # ~$0.008/hr
backend_machine_type  = "e2-micro"
use_preemptible       = true            # 70% cheaper, may restart

frontend_min_replicas = 1
frontend_max_replicas = 3
backend_min_replicas  = 1
backend_max_replicas  = 3

db_tier     = "db-g1-small"             # ~$0.05/hr
db_password = "your-strong-password"    # Stored in Secret Manager
```

Or skip the file and use the interactive setup: `./setup.sh`

## Manual Deploy (without setup.sh)

```bash
terraform init
terraform plan
terraform apply
```

## Useful Commands

```bash
# See what's deployed
terraform output

# SSH into an instance (via IAP, no public IP needed)
gcloud compute ssh frontend-demo-XXXX --tunnel-through-iap

# Tear down everything (stop billing)
terraform destroy
```

## Cost

Estimated ~$3-5/day with default settings (preemptible e2-micro + db-g1-small).

**Always run `terraform destroy` when you're done.**

## Architecture Decisions

See [docs/architecture.md](docs/architecture.md) for detailed design decisions including:
- Why Private Services Access for Cloud SQL (not just "private IP")
- Why separate service accounts per tier
- Why Cloud Armor is attached at the LB level
- Org policy constraints (enterprise context)

## License

MIT
