# -------- List --------
locals {
  gcp_secrets = [
    google_secret_manager_secret.r2_key_id.id,
    google_secret_manager_secret.r2_key.id,
    google_secret_manager_secret.backup_pass.id,
    google_secret_manager_secret.admin_token_hash.id,
    google_secret_manager_secret.vault_tunnel_token.id,
  ]
}

# -------- Reader Role Update --------
resource "google_secret_manager_secret_iam_member" "vm_secret_access" {
  for_each  = toset(local.gcp_secrets)
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${data.google_compute_default_service_account.default.email}"

  depends_on = [
    google_secret_manager_secret_version.r2_key_val,
    google_secret_manager_secret_version.r2_key_id_val,
    google_secret_manager_secret_version.backup_pass_val,
    google_secret_manager_secret_version.admin_token_hash_val,
    google_secret_manager_secret_version.vault_tunnel_token_val,
  ]
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
