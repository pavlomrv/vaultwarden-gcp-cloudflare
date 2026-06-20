terraform {
  required_version = "~> 1.15.1"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.region
}

# --- Required Variables ---
variable "gcp_project_id" {
  type        = string
  description = "The ID of the Google Cloud Project where resources will be created. This should match the project ID used in the main deployment."
}

variable "terraform_state_impersonators" {
  type        = set(string)
  description = "A list of service accounts or user emails authorized to impersonate the Terraform state service account."
}

variable "region" {
  type        = string
  description = "The Google Cloud region to deploy resources into."
  default     = "us-east1"
}

variable "tfstate_bucket_name" {
  type        = string
  description = "The name of the Google Cloud Storage bucket used to store Terraform state. This must be globally unique."
}

# --- Terraform State Storage Bucket ---
resource "google_storage_bucket" "tfstate" {
  name                        = var.tfstate_bucket_name
  location                    = var.region
  storage_class               = "STANDARD"
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

# --- IAM Configuration and Service Accounts ---
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

# --- Enable GCP Services ---
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
resource "google_project_service" "iam_api" {
  project            = var.gcp_project_id
  service            = "iam.googleapis.com"
  disable_on_destroy = false
}
resource "google_project_service" "crm_api" {
  project            = var.gcp_project_id
  service            = "cloudresourcemanager.googleapis.com"
  disable_on_destroy = false
}
# --- Outputs ---
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
