# VaultWarden
variable "vw_admin_token_hash" { sensitive = true }
variable "vw_backup_password" { sensitive = true }
variable "vw_backup_cron" { default = "0 2 * * *" }
variable "vw_backup_keep_days" { default = "180" }

# GCP
variable "gcp_region" { default = "us-east1" }
variable "gcp_zone" { default = "us-east1-b" }
variable "gcp_project_id" { sensitive = true }
variable "gcp_service_account" { sensitive = true }

# Cloudflare
variable "cf_domain" {}    # 'domain.com'
variable "cf_subdomain" {} # basically a subdomain, like 'vault in 'vault.domain.com'
variable "cf_api_token" { sensitive = true }
variable "cf_account_id" { sensitive = true }
variable "cf_zone_id" { sensitive = true }
variable "cf_r2_key_id" { sensitive = true }
variable "cf_r2_key" { sensitive = true }

# Docker
variable "vaultwarden_server_version" { default = "1.36.0" }
variable "cloudflare_cloudflared_version" { default = "2026.5.1" }
variable "ttionya_vaultwarden_backup_version" { default = "1.26.10" }
