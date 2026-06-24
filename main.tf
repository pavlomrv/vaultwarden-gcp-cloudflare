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
    # Deliberately left blank (partial backend configuration).
    # Configuration parameters are pulled from your local backend.config file.
    # Initialize using: terraform init -backend-config=backend.config
    # See backend.config.example for setup instructions.
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
