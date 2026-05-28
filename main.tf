terraform {
  required_version = "~> 1.15.1"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
  backend "gcs" {
    bucket                      = var.gcs_bucket
    prefix                      = var.gcs_prefix
    impersonate_service_account = "${var.gcs_service_account_id}@${var.gcp_project_id}.iam.gserviceaccount.com"
  }
}

provider "google" {
  project                     = var.gcp_project_id
  region                      = var.gcp_region
  zone                        = var.gcp_zone
  impersonate_service_account = var.gcp_service_account
}

provider "cloudflare" {
  api_token = var.cf_api_token
}
