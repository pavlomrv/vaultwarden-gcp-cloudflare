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
    bucket                      = "vaultwarden-tfstate"
    prefix                      = "terraform/state"
    impersonate_service_account = "" # is in backend-config file
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
