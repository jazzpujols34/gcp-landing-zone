#!/bin/bash
# =============================================================================
# GCP Landing Zone — Interactive Setup
# Clone the repo, run this script, answer the questions, deploy a 3-tier app.
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No color

print_banner() {
  echo ""
  echo -e "${CYAN}${BOLD}"
  echo "  ┌─────────────────────────────────────────────────┐"
  echo "  │     GCP Landing Zone — 3-Tier App Setup         │"
  echo "  │                                                 │"
  echo "  │  Cloud CDN → Load Balancer → GCE → Cloud SQL   │"
  echo "  │                                                 │"
  echo "  │  This script will:                              │"
  echo "  │    1. Check prerequisites                       │"
  echo "  │    2. Ask you a few questions                   │"
  echo "  │    3. Generate terraform.tfvars                 │"
  echo "  │    4. Deploy the entire stack                   │"
  echo "  └─────────────────────────────────────────────────┘"
  echo -e "${NC}"
}

print_step() {
  echo ""
  echo -e "${BLUE}${BOLD}[$1/$TOTAL_STEPS] $2${NC}"
  echo -e "${BLUE}$(printf '%.0s─' {1..50})${NC}"
}

print_success() {
  echo -e "  ${GREEN}✓${NC} $1"
}

print_warning() {
  echo -e "  ${YELLOW}!${NC} $1"
}

print_error() {
  echo -e "  ${RED}✗${NC} $1"
}

ask() {
  local prompt="$1"
  local default="$2"
  local var_name="$3"
  local sensitive="$4"

  if [ -n "$default" ]; then
    echo -e -n "  ${BOLD}$prompt${NC} [${GREEN}$default${NC}]: "
  else
    echo -e -n "  ${BOLD}$prompt${NC}: "
  fi

  if [ "$sensitive" = "true" ]; then
    read -s input
    echo ""
  else
    read input
  fi

  if [ -z "$input" ] && [ -n "$default" ]; then
    eval "$var_name='$default'"
  elif [ -z "$input" ] && [ -z "$default" ]; then
    print_error "This field is required."
    ask "$prompt" "$default" "$var_name" "$sensitive"
  else
    eval "$var_name='$input'"
  fi
}

ask_yes_no() {
  local prompt="$1"
  local default="$2"
  local var_name="$3"

  echo -e -n "  ${BOLD}$prompt${NC} [${GREEN}$default${NC}]: "
  read input
  input="${input:-$default}"

  case "$input" in
    [yY]|[yY][eE][sS]) eval "$var_name=true" ;;
    [nN]|[nN][oO]) eval "$var_name=false" ;;
    *) eval "$var_name=$default" ;;
  esac
}

TOTAL_STEPS=5

# =============================================================================
# Banner
# =============================================================================
print_banner

# =============================================================================
# Step 1: Prerequisites Check
# =============================================================================
print_step 1 "Checking prerequisites"

PREREQ_PASS=true

# Check Terraform
if command -v terraform &> /dev/null; then
  TF_VERSION=$(terraform version -json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['terraform_version'])" 2>/dev/null || terraform version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  print_success "Terraform $TF_VERSION installed"
else
  print_error "Terraform not found. Install: https://developer.hashicorp.com/terraform/install"
  PREREQ_PASS=false
fi

# Check gcloud
if command -v gcloud &> /dev/null; then
  GCLOUD_ACCOUNT=$(gcloud config get-value account 2>/dev/null)
  if [ -n "$GCLOUD_ACCOUNT" ] && [ "$GCLOUD_ACCOUNT" != "(unset)" ]; then
    print_success "gcloud authenticated as $GCLOUD_ACCOUNT"
  else
    print_error "gcloud installed but not authenticated. Run: gcloud auth login"
    PREREQ_PASS=false
  fi
else
  print_error "gcloud CLI not found. Install: https://cloud.google.com/sdk/docs/install"
  PREREQ_PASS=false
fi

# Check application-default credentials
if gcloud auth application-default print-access-token &> /dev/null; then
  print_success "Application Default Credentials configured"
else
  print_warning "Application Default Credentials not set."
  echo -e "       Run: ${CYAN}gcloud auth application-default login${NC}"
  PREREQ_PASS=false
fi

if [ "$PREREQ_PASS" = false ]; then
  echo ""
  print_error "Fix the issues above and re-run this script."
  exit 1
fi

# =============================================================================
# Step 2: Project Configuration
# =============================================================================
print_step 2 "Project configuration"

echo -e "  ${YELLOW}Answer the following questions. Press Enter to accept defaults.${NC}"
echo ""

# Try to detect current GCP project
DEFAULT_PROJECT=$(gcloud config get-value project 2>/dev/null)
if [ "$DEFAULT_PROJECT" = "(unset)" ]; then
  DEFAULT_PROJECT=""
fi

ask "GCP Project ID" "$DEFAULT_PROJECT" PROJECT_ID
echo ""

# Validate project exists and has billing
echo -e "  Validating project ${CYAN}$PROJECT_ID${NC}..."
if gcloud projects describe "$PROJECT_ID" &> /dev/null; then
  print_success "Project exists"
else
  print_error "Project '$PROJECT_ID' not found or you don't have access."
  echo -e "       Create one: ${CYAN}gcloud projects create $PROJECT_ID${NC}"
  exit 1
fi

# Check billing
BILLING_ENABLED=$(gcloud billing projects describe "$PROJECT_ID" --format="value(billingEnabled)" 2>/dev/null || echo "false")
if [ "$BILLING_ENABLED" = "True" ]; then
  print_success "Billing is enabled"
else
  print_warning "Billing may not be enabled. Terraform will fail without billing."
  echo -e "       Enable at: ${CYAN}https://console.cloud.google.com/billing/linkedaccount?project=$PROJECT_ID${NC}"
  echo ""
  ask_yes_no "Continue anyway?" "no" CONTINUE_WITHOUT_BILLING
  if [ "$CONTINUE_WITHOUT_BILLING" = "false" ]; then
    exit 1
  fi
fi

echo ""

# =============================================================================
# Step 3: Infrastructure Sizing
# =============================================================================
print_step 3 "Infrastructure sizing"

echo -e "  ${YELLOW}Configure the size and cost of your deployment.${NC}"
echo ""

# Region
echo -e "  ${BOLD}Available regions (pick one close to your users):${NC}"
echo -e "    ${CYAN}asia-east1${NC}      Taiwan"
echo -e "    ${CYAN}us-central1${NC}     Iowa, USA"
echo -e "    ${CYAN}europe-west1${NC}    Belgium"
echo -e "    ${CYAN}asia-northeast1${NC} Tokyo"
echo ""
ask "Region" "asia-east1" REGION

# Zone (derive from region)
DEFAULT_ZONE="${REGION}-b"
ask "Zone" "$DEFAULT_ZONE" ZONE

# Environment label
ask "Environment name" "demo" ENVIRONMENT

echo ""
echo -e "  ${BOLD}Compute sizing:${NC}"
echo -e "    ${CYAN}e2-micro${NC}   0.25 vCPU, 1GB RAM  (~\$0.008/hr)  — good for demo"
echo -e "    ${CYAN}e2-small${NC}   0.5 vCPU, 2GB RAM   (~\$0.017/hr)  — light workloads"
echo -e "    ${CYAN}e2-medium${NC}  1 vCPU, 4GB RAM      (~\$0.034/hr)  — moderate"
echo ""
ask "Frontend machine type" "e2-micro" FE_MACHINE_TYPE
ask "Backend machine type" "e2-micro" BE_MACHINE_TYPE

echo ""
ask_yes_no "Use preemptible/spot instances? (70% cheaper, may restart)" "yes" USE_PREEMPTIBLE

echo ""
echo -e "  ${BOLD}Autoscaling (instances per tier):${NC}"
ask "Frontend min replicas" "1" FE_MIN
ask "Frontend max replicas" "3" FE_MAX
ask "Backend min replicas" "1" BE_MIN
ask "Backend max replicas" "3" BE_MAX

echo ""
echo -e "  ${BOLD}Database:${NC}"
echo -e "    ${CYAN}db-g1-small${NC}   0.5 vCPU, 1.7GB RAM  (~\$0.05/hr)"
echo -e "    ${CYAN}db-custom-1-3840${NC}  1 vCPU, 3.75GB   (~\$0.10/hr)"
echo ""
ask "Cloud SQL tier" "db-g1-small" DB_TIER

echo ""
echo -e "  ${YELLOW}Set a password for the PostgreSQL database user.${NC}"
echo -e "  ${YELLOW}(Use a strong password — this will be stored in Secret Manager)${NC}"
ask "Database password" "" DB_PASSWORD "true"

# Validate password length
if [ ${#DB_PASSWORD} -lt 8 ]; then
  print_error "Password must be at least 8 characters."
  exit 1
fi

# =============================================================================
# Step 4: Review & Confirm
# =============================================================================
print_step 4 "Review your configuration"

echo ""
echo -e "  ${BOLD}Project${NC}"
echo -e "    Project ID:    ${CYAN}$PROJECT_ID${NC}"
echo -e "    Region:        ${CYAN}$REGION${NC}"
echo -e "    Zone:          ${CYAN}$ZONE${NC}"
echo -e "    Environment:   ${CYAN}$ENVIRONMENT${NC}"
echo ""
echo -e "  ${BOLD}Compute${NC}"
echo -e "    Frontend:      ${CYAN}$FE_MACHINE_TYPE${NC} x ${CYAN}$FE_MIN-$FE_MAX${NC} instances"
echo -e "    Backend:       ${CYAN}$BE_MACHINE_TYPE${NC} x ${CYAN}$BE_MIN-$BE_MAX${NC} instances"
echo -e "    Preemptible:   ${CYAN}$USE_PREEMPTIBLE${NC}"
echo ""
echo -e "  ${BOLD}Database${NC}"
echo -e "    Tier:          ${CYAN}$DB_TIER${NC}"
echo -e "    Password:      ${CYAN}********${NC}"
echo ""

# Cost estimate
echo -e "  ${BOLD}Estimated cost:${NC} ${YELLOW}~\$3-5/day${NC} (destroy when not using!)"
echo ""

ask_yes_no "Deploy this stack?" "yes" CONFIRM_DEPLOY

if [ "$CONFIRM_DEPLOY" = "false" ]; then
  echo ""
  echo -e "  Config written to ${CYAN}terraform.tfvars${NC}. Deploy later with:"
  echo -e "    ${CYAN}terraform init && terraform apply${NC}"

  # Still write the file even if they don't deploy now
  cat > terraform.tfvars <<EOF
project_id  = "$PROJECT_ID"
region      = "$REGION"
zone        = "$ZONE"
environment = "$ENVIRONMENT"

frontend_machine_type = "$FE_MACHINE_TYPE"
backend_machine_type  = "$BE_MACHINE_TYPE"
use_preemptible       = $USE_PREEMPTIBLE
frontend_min_replicas = $FE_MIN
frontend_max_replicas = $FE_MAX
backend_min_replicas  = $BE_MIN
backend_max_replicas  = $BE_MAX

db_tier     = "$DB_TIER"
db_password = "$DB_PASSWORD"
EOF

  print_success "terraform.tfvars written."
  exit 0
fi

# =============================================================================
# Step 5: Deploy
# =============================================================================
print_step 5 "Deploying infrastructure"

# Write terraform.tfvars
cat > terraform.tfvars <<EOF
project_id  = "$PROJECT_ID"
region      = "$REGION"
zone        = "$ZONE"
environment = "$ENVIRONMENT"

frontend_machine_type = "$FE_MACHINE_TYPE"
backend_machine_type  = "$BE_MACHINE_TYPE"
use_preemptible       = $USE_PREEMPTIBLE
frontend_min_replicas = $FE_MIN
frontend_max_replicas = $FE_MAX
backend_min_replicas  = $BE_MIN
backend_max_replicas  = $BE_MAX

db_tier     = "$DB_TIER"
db_password = "$DB_PASSWORD"
EOF

print_success "terraform.tfvars written"

echo ""
echo -e "  Running ${CYAN}terraform init${NC}..."
terraform init

echo ""
echo -e "  Running ${CYAN}terraform plan${NC}..."
terraform plan -out=tfplan

echo ""
ask_yes_no "Apply this plan?" "yes" CONFIRM_APPLY

if [ "$CONFIRM_APPLY" = "false" ]; then
  echo -e "  Plan saved to ${CYAN}tfplan${NC}. Apply later with: ${CYAN}terraform apply tfplan${NC}"
  exit 0
fi

echo ""
echo -e "  Running ${CYAN}terraform apply${NC}..."
terraform apply tfplan

echo ""
echo -e "${GREEN}${BOLD}"
echo "  ┌─────────────────────────────────────────────────┐"
echo "  │              Deployment Complete!                │"
echo "  └─────────────────────────────────────────────────┘"
echo -e "${NC}"

# Show outputs
LB_IP=$(terraform output -raw load_balancer_ip 2>/dev/null || echo "pending")
echo -e "  ${BOLD}Load Balancer IP:${NC}  ${CYAN}http://$LB_IP${NC}"
echo -e "  ${BOLD}Cloud SQL:${NC}         ${CYAN}$(terraform output -raw cloud_sql_private_ip 2>/dev/null || echo "pending")${NC} (private)"
echo -e "  ${BOLD}GCS Bucket:${NC}        ${CYAN}$(terraform output -raw gcs_bucket_url 2>/dev/null || echo "pending")${NC}"
echo ""
echo -e "  ${YELLOW}Note: Load balancer may take 5-10 minutes to become healthy.${NC}"
echo ""
echo -e "  ${BOLD}Useful commands:${NC}"
echo -e "    ${CYAN}terraform output${NC}              Show all outputs"
echo -e "    ${CYAN}terraform destroy${NC}             Tear down everything (stop billing)"
echo -e "    ${CYAN}gcloud compute ssh frontend-${ENVIRONMENT}-XXXX --tunnel-through-iap${NC}  SSH into instance"
echo ""
echo -e "  ${RED}${BOLD}IMPORTANT: Run 'terraform destroy' when done to avoid charges!${NC}"
echo ""
