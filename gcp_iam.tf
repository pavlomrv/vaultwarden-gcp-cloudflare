# -------- List --------
locals {
  gcp_secrets = {
    "r2_key_id"          = google_secret_manager_secret.r2_key_id.id,
    "r2_key"             = google_secret_manager_secret.r2_key.id,
    "backup_pass"        = google_secret_manager_secret.backup_pass.id,
    "admin_token_hash"   = google_secret_manager_secret.admin_token_hash.id,
    "vault_tunnel_token" = google_secret_manager_secret.vault_tunnel_token.id,
  }
}

# -------- Reader Role Update --------
resource "google_service_account" "vaultwarden_vm_sa" {
  account_id   = "vaultwarden-vm-sa"
  display_name = "Vaultwarden VM Identity"
}

# -------- Allow Google Cloud Logging --------
resource "google_project_iam_member" "vm_logging" {
  project = var.gcp_project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.vaultwarden_vm_sa.email}"
}
# -------- Allow Reading Each Secret --------
resource "google_secret_manager_secret_iam_member" "vm_secret_access" {
  for_each  = local.gcp_secrets
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.vaultwarden_vm_sa.email}"
}

# -------- Access to the bucket tha holds the backup restore script  --------
resource "google_storage_bucket_iam_member" "vm_restore_script_viewer" {
  bucket = google_storage_bucket.restore_script_bucket.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.vaultwarden_vm_sa.email}"
}

# -------- Secrets --------
resource "google_secret_manager_secret" "r2_key_id" {
  secret_id = "r2_key_id"
  replication {
    auto {}
  }
}
resource "google_secret_manager_secret_version" "r2_key_id_val" {
  secret                 = google_secret_manager_secret.r2_key_id.id
  secret_data_wo         = var.cf_r2_key_id
  deletion_policy        = "DISABLE"
  secret_data_wo_version = "1"
}

# --------
resource "google_secret_manager_secret" "r2_key" {
  secret_id = "r2_key"
  replication {
    auto {}
  }
}
resource "google_secret_manager_secret_version" "r2_key_val" {
  secret                 = google_secret_manager_secret.r2_key.id
  secret_data_wo         = var.cf_r2_key
  deletion_policy        = "DISABLE"
  secret_data_wo_version = "1"
}

# --------
resource "google_secret_manager_secret" "backup_pass" {
  secret_id = "backup_pass"
  replication {
    auto {}
  }
}
resource "google_secret_manager_secret_version" "backup_pass_val" {
  secret                 = google_secret_manager_secret.backup_pass.id
  secret_data_wo         = var.vw_backup_password
  deletion_policy        = "DISABLE"
  secret_data_wo_version = "1"
}

# --------
resource "google_secret_manager_secret" "admin_token_hash" {
  secret_id = "admin_token_hash"
  replication {
    auto {}
  }
}
resource "google_secret_manager_secret_version" "admin_token_hash_val" {
  secret                 = google_secret_manager_secret.admin_token_hash.id
  secret_data_wo         = var.vw_admin_token_hash
  deletion_policy        = "DISABLE"
  secret_data_wo_version = "1"
}

# --------
resource "google_secret_manager_secret" "vault_tunnel_token" {
  secret_id = "vault_tunnel_token"
  replication {
    auto {}
  }
}
resource "google_secret_manager_secret_version" "vault_tunnel_token_val" {
  secret                 = google_secret_manager_secret.vault_tunnel_token.id
  secret_data_wo         = data.cloudflare_zero_trust_tunnel_cloudflared_token.vault_tunnel.token
  deletion_policy        = "DISABLE"
  secret_data_wo_version = "1"
}
