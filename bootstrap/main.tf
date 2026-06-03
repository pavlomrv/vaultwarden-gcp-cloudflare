terraform {
  required_version = "~> 1.15.1"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7"
    }
    # cloudflare = {
    #   source  = "cloudflare/cloudflare"
    #   version = "~> 5"
    # }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.region
}

variable "gcp_project_id" { type = string }
variable "terraform_state_impersonators" { type = set(string) }
variable "region" {
  type    = string
  default = "us-east1"
}
variable "tfstate_bucket" {
  type    = string
  default = "vaultwarden-tfstate"
}

# -------- tfstate bucket
resource "google_storage_bucket" "tfstate" {
  name                        = var.tfstate_bucket
  location                    = var.region
  force_destroy               = false
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }

    condition {
      age        = 90
      with_state = "ARCHIVED"
    }
  }
}

# -------- IAM stuff
resource "google_service_account" "terraform_state" {
  account_id   = "terraform-state"
  display_name = "Terraform state bucket access"
}
resource "google_storage_bucket_iam_member" "terraform_state_object_admin" {
  bucket = google_storage_bucket.tfstate.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.terraform_state.email}"
}
resource "google_service_account_iam_member" "terraform_state_impersonators" {
  for_each           = var.terraform_state_impersonators
  member             = each.value
  service_account_id = google_service_account.terraform_state.name
  role               = "roles/iam.serviceAccountTokenCreator"
}

# # -------- Cloudflare api token here? TODO
# ⚠️ The Ultimate R2 "Gotcha" in Terraform
#
# There is a huge architectural distinction that trips up a lot of self-hosters here:
#
# The ttionya/vaultwarden-backup container relies on rclone under the hood, which interacts with R2 using the S3-compatible API. To do this, it absolutely requires an S3 Access Key ID and an S3 Secret Access Key.
#
# The standard cloudflare_api_token resource in Terraform (even in v5) cannot generate or export S3-compatible Access Keys. It can only generate tokens meant for the native Cloudflare HTTP API (like creating or deleting an entire bucket container).
#
# What this means for you:
# If your ttionya container is successfully talking to R2 right now, you almost certainly did not create those keys via Terraform. You likely generated them manually in the Cloudflare Dashboard under R2 > Manage R2 API Tokens, where Cloudflare explicitly hands you an S3 Access Key Pair.
#
# To double-check those permissions, skip the Terraform code entirely and head to your Cloudflare Web Console to ensure that specific token is marked as Object Read & Write.
# data "cloudflare_api_token_permissions_groups_list" "all" {}
#
# # In v5, look to see if you are parsing the list for "Write" strings
# locals {
#   r2_write_id = element([
#     for g in data.cloudflare_api_token_permissions_groups_list.all.result : g.id
#     if g.name == "Workers R2 Storage Bucket Item Write"
#   ], 0)
# }
# resource "cloudflare_api_token" "vaultwarden_backup_token" {
#   name = "vaultwarden-r2-backup-token"
#
#   # v5 uses the 'policies' list of objects
#   policies = [{
#     effect = "allow"
#
#     # You must look for these permission group IDs
#     permission_groups = [
#       {
#         # Example UUID for R2 Bucket Item Write
#         id = "7f7bc863dc364f9b93e4bf4753be62e4"
#       },
#       {
#         # Example UUID for R2 Bucket Item Read
#         id = "c31671e9a3b64c7e8d8ee27e573e86c0"
#       }
#     ]
#
#     resources = {
#       "com.cloudflare.edge.r2.bucket.*" = "*"
#     }
#   }]
# }
# -------- Enable GCP services
resource "google_project_service" "compute_api" {
  project            = var.gcp_project_id
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}
resource "google_project_service" "secret_manager_api" {
  project            = var.gcp_project_id
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}
resource "google_project_service" "iam_credentials" {
  project                    = var.gcp_project_id
  service                    = "iamcredentials.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
}

# -------- Outputs
output "backend_bucket_name" {
  description = "The exact name of the GCS bucket to use in your backend config."
  value       = google_storage_bucket.tfstate.name
}
output "backend_impersonate_service_account" {
  description = "The exact service account email to use for backend impersonation."
  value       = google_service_account.terraform_state.email
}
output "authorized_impersonators" {
  description = "The list of users/identities authorized to impersonate the state service account."
  value       = var.terraform_state_impersonators
}
