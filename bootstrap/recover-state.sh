#!/usr/bin/env bash

set -euo pipefail

show_usage() {
  local script_name
  script_name=$(basename "$0")

  cat << EOF
----------------------------------------------------------------------

Bootstrap TF State Restore Script

Recreates Terraform's local state by importing existing GCP resources.
This is useful when the bootstrap local state file is lost and you
need to re-sync Terraform with infrastructure that already exists.
It does NOT restore old state history — it creates a fresh local state.

USAGE:
  bash ./${script_name} [-h|--help] [IMPERSONATOR ...]

  Run from the bootstrap/ directory. Each IMPERSONATOR should match an
  entry in your 'terraform_state_impersonators' variable, formatted as:
    user:<email>  or  serviceAccount:<email>

CONFIGURATION:
  The script resolves settings from three sources (highest priority first):
    1. Environment variables
    2. Values parsed from terraform.tfvars (in the current directory)
    3. Interactive prompt (fallback)

  Environment Variables (all optional):
    PROJECT_ID        GCP project ID.
    TFSTATE_BUCKET    Name of the GCS bucket holding Terraform state (for the main module).

EXAMPLE:
  cd bootstrap
  PROJECT_ID=my-project TFSTATE_BUCKET=my-tfstate-bucket \\
    ./${script_name} \\
      user:me@example.com \\
      serviceAccount:ci@my-project.iam.gserviceaccount.com

IMPORTANT:
  - After the import, 'terraform plan' runs automatically. The diff
    should be empty or trivially small. If Terraform wants to destroy
    or recreate critical resources, stop and inspect before applying!
  - This script uses '-backend=false' so no remote state is touched.
  - Pass the same impersonators you use in terraform_state_impersonators;
    otherwise the recovery plan may want to remove missing IAM bindings.
----------------------------------------------------------------------
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  show_usage
  exit 0
fi

# Helper function to extract string variables from terraform.tfvars
parse_tfvar() {
  local key="$1"
  if [[ -f "terraform.tfvars" ]]; then
    # Matches 'key = "value"' formats while tolerating variable spacing
    sed -n "s/^${key} *= *\"\\([^\"]*\\)\".*/\\1/p" terraform.tfvars
  fi
}

echo "--- Configuration Discovery ---"

# 1. Resolve Project ID (Env -> tfvars -> Prompt)
TFVARS_PROJECT=$(parse_tfvar "gcp_project_id")
DEFAULT_PROJECT="${PROJECT_ID:-$TFVARS_PROJECT}"

if [[ -n "$DEFAULT_PROJECT" ]]; then
  read -r -p "GCP Project ID [${DEFAULT_PROJECT}]: " INPUT_PROJECT
  PROJECT_ID="${INPUT_PROJECT:-$DEFAULT_PROJECT}"
else
  read -r -p "Enter GCP Project ID (Required): " PROJECT_ID
fi

if [[ -z "${PROJECT_ID:-}" ]]; then
  echo "Error: PROJECT_ID is mandatory to map infrastructure assets." >&2
  exit 1
fi

# 2. Resolve TF State Bucket Name (Env -> tfvars -> Prompt)
TFVARS_BUCKET=$(parse_tfvar "tfstate_bucket_name")
DEFAULT_BUCKET="${TFSTATE_BUCKET:-$TFVARS_BUCKET}"
read -r -p "Terraform State Bucket Name [${DEFAULT_BUCKET}]: " INPUT_BUCKET
TFSTATE_BUCKET="${INPUT_BUCKET:-$DEFAULT_BUCKET}"

if [[ -z "${TFSTATE_BUCKET:-}" ]]; then
  echo "Error: TFSTATE_BUCKET is mandatory to map infrastructure assets." >&2
  exit 1
fi


# Derived variables

# Service Account ID is hardcoded in bootstrap/main.tf -> google_service_account.terraform_state
STATE_SA_EMAIL="terraform-state@${PROJECT_ID}.iam.gserviceaccount.com"

IMPERSONATORS=("$@")

# Build HCL array for Terraform execution
members_hcl="["
sep=""
for member in ${IMPERSONATORS[@]+"${IMPERSONATORS[@]}"}; do
  members_hcl="${members_hcl}${sep}\"${member}\""
  sep=","
done
members_hcl="${members_hcl}]"

# Export environment variables for Terraform
export TF_VAR_gcp_project_id="$PROJECT_ID"
export TF_VAR_tfstate_bucket_name="$TFSTATE_BUCKET"
export TF_VAR_terraform_state_impersonators="$members_hcl"

echo -e "\n-----------------------------------------------------"
echo "  READY TO RECOVER STATE WITH THE FOLLOWING PROFILE:"
echo "-----------------------------------------------------"
echo "  GCP Project ID:   $PROJECT_ID"
echo "  State Bucket:     $TFSTATE_BUCKET"
echo "  Service Account:  $STATE_SA_EMAIL"
echo "  Impersonators:    ${IMPERSONATORS[*]:-None provided}"
echo "-----------------------------------------------------"
read -r -p "Proceed with generating local state? (y/N): " FINAL_CONFIRM
if [[ ! "$FINAL_CONFIRM" =~ ^[Yy]$ ]]; then
  echo "State recovery aborted by user."
  exit 0
fi

echo "--- Init and Import ---"
terraform init -backend=false

import_if_missing() {
  local address="$1"
  local id="$2"

  if terraform state show -no-color "$address" >/dev/null 2>&1; then
    echo "Already in state: $address"
  else
    echo "Importing resource: $address"
    terraform import "$address" "$id"
  fi
}

# --- Core Resources ---
import_if_missing google_storage_bucket.tfstate "${PROJECT_ID}/${TFSTATE_BUCKET}"
import_if_missing google_service_account.terraform_state "projects/${PROJECT_ID}/serviceAccounts/${STATE_SA_EMAIL}"
import_if_missing google_storage_bucket_iam_member.terraform_state_object_admin \
  "b/${TFSTATE_BUCKET} roles/storage.objectAdmin serviceAccount:${STATE_SA_EMAIL}"

for member in "${IMPERSONATORS[@]}"; do
  import_if_missing \
    "google_service_account_iam_member.terraform_state_impersonators[\"${member}\"]" \
    "projects/${PROJECT_ID}/serviceAccounts/${STATE_SA_EMAIL} roles/iam.serviceAccountTokenCreator ${member}"
done

# --- Project Services ---
import_if_missing google_project_service.compute_api "${PROJECT_ID}/compute.googleapis.com"
import_if_missing google_project_service.secret_manager_api "${PROJECT_ID}/secretmanager.googleapis.com"
import_if_missing google_project_service.iam_credentials "${PROJECT_ID}/iamcredentials.googleapis.com"
import_if_missing google_project_service.iam_api "${PROJECT_ID}/iam.googleapis.com"
import_if_missing google_project_service.crm_api "${PROJECT_ID}/cloudresourcemanager.googleapis.com"

echo "---------------------------------------------------------------------"
echo "Import phase complete. Running plan to verify state alignment..."
echo "---------------------------------------------------------------------"
terraform plan
