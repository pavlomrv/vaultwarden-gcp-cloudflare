terraform {
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

variable "gcp_project_id" {}
variable "region" { default = "us-east1" }
variable "tfstate_bucket" { default = "vaultwarden-tfstate" }
variable "terraform_state_impersonators" {
  type = set(string)
}

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