# --- Vaultwarden Variables ---
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
  default = "0 0 * * *" # At 00:00 UTC
}
variable "vw_backup_keep_days" {
  type    = string
  default = "180"
}

# --- GCP Configuration ---
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
variable "gcp_restore_script_bucket_name" { type = string }

# --- Cloudflare Configuration ---
variable "cf_domain" { # Cloudflare root domain (e.g., 'domain.com')
  type = string
}
variable "cf_subdomain" { # The subdomain prefix (e.g., 'vault' for 'vault.domain.com')
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
variable "cf_r2_backup_bucket_name" {
  type        = string
  description = "Cloudflare R2 bucket name used for Vaultwarden backups."
}
variable "cf_r2_location" {
  type        = string
  description = "Cloudflare R2 bucket location hint. Note that the free tier is limited to specific locations."
  default     = "enam" # Eastern North America
}
variable "cf_tunnel_name" {
  type    = string
  default = "vaultwarden-gcp-tunnel"
}

# --- Docker Configuration ---
variable "vaultwarden_server_container_hash" {
  type    = string
  default = "sha256:d626d04934cd1192ad8ced1adb975099fca78cec33ab467d2d3c923cde7f3b0c" # 1.36.0
}
variable "cloudflare_cloudflared_container_hash" {
  type    = string
  default = "sha256:6d91c121b803126f7a5344005d17a9324788fc09d305b6e2560ec6040a7ae283" # 2026.6.1
}
variable "ttionya_vaultwarden_backup_container_hash" {
  type    = string
  default = "sha256:0393b16f850889c1ee509e5734110c06db812ad2e583b52aa1bce16c986e03a5" # 1.26.11
}
