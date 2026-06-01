#!/usr/bin/env bash


#Usage:

#cd bootstrap
#PROJECT_ID=my-project ./recover-state.sh user:me@example.com

#Or with multiple impersonators:

#PROJECT_ID=my-project ./recover-state.sh \
#  user:me@example.com \
#  serviceAccount:ci@my-project.iam.gserviceaccount.com

#Important details:
#- Pass the same impersonators you used for `terraform_state_impersonators`.
#- The script recreates Terraform’s local state by importing existing GCP resources; it does not restore old state history.
#- After it runs, `terraform plan` should be empty or very small. If it wants to recreate the bucket or service account, stop and inspect before applying.

#TODO review this

set -euo pipefail

PROJECT_ID="${PROJECT_ID:?Set PROJECT_ID, e.g. PROJECT_ID=my-gcp-project}"
TFSTATE_BUCKET="${TFSTATE_BUCKET:-vaultwarden-tfstate}"
STATE_SA_ID="${STATE_SA_ID:-terraform-state}"
STATE_SA_EMAIL="${STATE_SA_ID}@${PROJECT_ID}.iam.gserviceaccount.com"

IMPERSONATORS=("$@")

members_hcl="["
sep=""
for member in "${IMPERSONATORS[@]}"; do
  members_hcl="${members_hcl}${sep}\"${member}\""
  sep=","
done
members_hcl="${members_hcl}]"

export TF_VAR_gcp_project_id="$PROJECT_ID"
export TF_VAR_tfstate_bucket="$TFSTATE_BUCKET"
export TF_VAR_terraform_state_impersonators="$members_hcl"

terraform init -backend=false

import_if_missing() {
  local address="$1"
  local id="$2"

  if terraform state show -no-color "$address" >/dev/null 2>&1; then
    echo "Already in state: $address"
  else
    echo "Importing: $address"
    terraform import "$address" "$id"
  fi
}

import_if_missing \
  google_storage_bucket.tfstate \
  "${PROJECT_ID}/${TFSTATE_BUCKET}"

import_if_missing \
  google_service_account.terraform_state \
  "projects/${PROJECT_ID}/serviceAccounts/${STATE_SA_EMAIL}"

import_if_missing \
  google_storage_bucket_iam_member.terraform_state_object_admin \
  "b/${TFSTATE_BUCKET} roles/storage.objectAdmin serviceAccount:${STATE_SA_EMAIL}"

for member in "${IMPERSONATORS[@]}"; do
  import_if_missing \
    "google_service_account_iam_member.terraform_state_impersonators[\"${member}\"]" \
    "projects/${PROJECT_ID}/serviceAccounts/${STATE_SA_EMAIL} roles/iam.serviceAccountTokenCreator ${member}"
done

import_if_missing google_project_service.compute_api "${PROJECT_ID}/compute.googleapis.com"
import_if_missing google_project_service.secret_manager_api "${PROJECT_ID}/secretmanager.googleapis.com"
import_if_missing google_project_service.iam_credentials "${PROJECT_ID}/iamcredentials.googleapis.com"

terraform plan
