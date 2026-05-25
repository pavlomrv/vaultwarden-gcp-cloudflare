# --- VARIABLES ---
variable "admin_token_hash" { sensitive = true }
variable "backup_password" { sensitive = true }

# GCP
variable "region" { default = "us-east1" }
variable "zone" { default = "us-east1-b" }
variable "gcp_project_id" { sensitive = true }
variable "service_account" { sensitive = true }


# Cloudflare
variable "cf_domain" {}
variable "cf_api_token" { sensitive = true }
variable "cf_account_id" { sensitive = true }
variable "cf_zone_id" { sensitive = true }
variable "r2_key_id" { sensitive = true }
variable "r2_key" { sensitive = true }