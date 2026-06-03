# VaultWarden
variable "vw_admin_token_hash" {
  type      = string
  sensitive = true
}
variable "vw_backup_password" {
  type      = string
  sensitive = true
}
variable "vw_backup_cron" {
  type    = string
  default = "0 20 * * *" # its in (ET), so here its ~3am
}
variable "vw_backup_keep_days" {
  type    = string
  default = "180"
}

# GCP
variable "gcp_region" {
  type    = string
  default = "us-east1"
}
variable "gcp_zone" {
  type    = string
  default = "us-east1-b"
}
variable "gcp_project_id" {
  type      = string
  sensitive = true
}
variable "gcp_service_account" {
  type      = string
  sensitive = true
}

# Cloudflare
variable "cf_domain" { # 'domain.com'
  type = string
}
variable "cf_subdomain" { # basically a subdomain, like 'vault in 'vault.domain.com'
  type = string
}
variable "cf_api_token" {
  type      = string
  sensitive = true
}
variable "cf_account_id" {
  type      = string
  sensitive = true
}
variable "cf_zone_id" {
  type      = string
  sensitive = true
}
variable "cf_r2_key_id" {
  type      = string
  sensitive = true
}
variable "cf_r2_key" {
  type      = string
  sensitive = true
}

# Docker
variable "vaultwarden_server_version" {
  type    = string
  default = "1.36.0"
}
variable "cloudflare_cloudflared_version" {
  type    = string
  default = "2026.5.1"
}
variable "ttionya_vaultwarden_backup_version" {
  type    = string
  default = "1.26.10"
}
