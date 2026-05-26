# --- VARIABLES ---
variable "admin_token_hash" { sensitive = true }
variable "backup_password" { sensitive = true }

# GCP
variable "region" { default = "us-east1" }
variable "zone" { default = "us-east1-b" }
variable "gcp_project_id" { sensitive = true }
variable "service_account" { sensitive = true }

# Cloudflare
variable "cf_domain" {}       # 'domain.com'
variable "cf_subdomain" {} # basically a subdomain, like 'vault in 'vault.domain.com'
variable "cf_api_token" { sensitive = true }
variable "cf_account_id" { sensitive = true }
variable "cf_zone_id" { sensitive = true }
variable "r2_key_id" { sensitive = true }
variable "r2_key" { sensitive = true }

# Etc
variable "vaultwarden_server_version" { default = "1.36.0" }
variable "cloudflare_cloudflared_version" { default = "2026.5.1" }
variable "ttionya_vaultwarden_backup_version" { default = "1.26.10" }
variable "backup_cron" { default = "0 2 * * *" }
variable "backup_keep_days" { default = "30" }
