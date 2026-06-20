# --- Vaultwarden Variables ---
variable "vw_admin_token_hash" {
  type        = string
  description = "The hashed admin token used for authenticating to the Vaultwarden admin panel."
  sensitive   = true
}
variable "vw_backup_password" {
  type        = string
  description = "The password used to encrypt the Vaultwarden SQLite database backups."
  sensitive   = true
}
variable "vw_backup_cron" {
  type        = string
  description = "The cron expression defining the schedule for Vaultwarden database backups."
  default     = "0 0 * * *" # At 00:00 UTC
}
variable "vw_backup_keep_days" {
  type        = string
  description = "The number of days to retain Vaultwarden database backups."
  default     = "180"
}

# --- GCP Configuration ---
variable "gcp_region" {
  type        = string
  description = "The default GCP region where resources will be provisioned."
  default     = "us-east1"
}
variable "gcp_zone" {
  type        = string
  description = "The GCP zone where compute resources, such as VMs, will be deployed."
  default     = "us-east1-b"
}
variable "gcp_project_id" {
  type        = string
  description = "The ID of the GCP project where the infrastructure will be created."
  sensitive   = true
}
variable "gcp_service_account" {
  type        = string
  description = "The GCP service account used for provisioning or running the application."
  sensitive   = true
}
variable "gcp_restore_script_bucket_name" {
  type        = string
  description = "The name of the GCS bucket storing the Vaultwarden database restore script."
}

# --- Cloudflare Configuration ---
variable "cf_domain" {
  type        = string
  description = "The Cloudflare root domain name (e.g., 'domain.com')."
}
variable "cf_subdomain" {
  type        = string
  description = "The subdomain prefix for the Vaultwarden instance (e.g., 'vault' for 'vault.domain.com')."
}
variable "cf_api_token" {
  type        = string
  description = "The Cloudflare API token used to manage DNS records and resources."
  sensitive   = true
}
variable "cf_account_id" {
  type        = string
  description = "The Cloudflare account ID."
  sensitive   = true
}
variable "cf_zone_id" {
  type        = string
  description = "The Cloudflare zone ID corresponding to the root domain."
  sensitive   = true
}
variable "cf_r2_key_id" {
  type        = string
  description = "The Cloudflare R2 access key ID for interacting with R2 buckets."
  sensitive   = true
}
variable "cf_r2_key" {
  type        = string
  description = "The Cloudflare R2 secret access key."
  sensitive   = true
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
  type        = string
  description = "The name of the Cloudflare Tunnel used to securely expose the Vaultwarden instance."
  default     = "vaultwarden-gcp-tunnel"
}

# --- Docker Configuration ---
variable "vaultwarden_server_container_hash" {
  type        = string
  description = "The specific image hash for the Vaultwarden server container."
  default     = "sha256:d626d04934cd1192ad8ced1adb975099fca78cec33ab467d2d3c923cde7f3b0c" # 1.36.0
}
variable "cloudflare_cloudflared_container_hash" {
  type        = string
  description = "The specific image hash for the Cloudflare cloudflared container."
  default     = "sha256:6d91c121b803126f7a5344005d17a9324788fc09d305b6e2560ec6040a7ae283" # 2026.6.1
}
variable "ttionya_vaultwarden_backup_container_hash" {
  type        = string
  description = "The specific image hash for the Vaultwarden backup container."
  default     = "sha256:0393b16f850889c1ee509e5734110c06db812ad2e583b52aa1bce16c986e03a5" # 1.26.11
}
