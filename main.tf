terraform {
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
    bucket = "vaultwarden-tfstate"
    prefix = "terraform/state"
  }
}

provider "google" {
  project                     = var.gcp_project_id
  region                      = var.region
  zone                        = var.zone
  impersonate_service_account = var.service_account
}

provider "cloudflare" {
  api_token = var.cf_api_token
}
