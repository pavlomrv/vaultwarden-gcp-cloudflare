# -------- List --------
locals {
  gcp_secrets = [
    google_secret_manager_secret.r2_key_id.id,
    google_secret_manager_secret.r2_key.id,
    google_secret_manager_secret.backup_pass.id,
    google_secret_manager_secret.admin_token_hash.id,
  ]
}

# -------- Reader Role Update --------
resource "google_secret_manager_secret_iam_member" "vm_secret_access" {
  for_each  = toset(local.gcp_secrets)
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}
data "google_compute_default_service_account" "default" {} # the Default Compute Service Account

# -------- Secrets --------
resource "google_secret_manager_secret" "r2_key_id" {
  secret_id = "r2_key_id"
  replication {
    auto {}
  }
}
resource "google_secret_manager_secret_version" "r2_key_id_val" {
  secret      = google_secret_manager_secret.r2_key_id.id
  secret_data = var.r2_key_id
}

# --------
resource "google_secret_manager_secret" "r2_key" {
  secret_id = "r2_key"
  replication {
    auto {}
  }
}
resource "google_secret_manager_secret_version" "r2_key_val" {
  secret      = google_secret_manager_secret.r2_key.id
  secret_data = var.r2_key
}

# --------
resource "google_secret_manager_secret" "backup_pass" {
  secret_id = "backup_pass"
  replication {
    auto {}
  }
}
resource "google_secret_manager_secret_version" "backup_pass_val" {
  secret      = google_secret_manager_secret.backup_pass.id
  secret_data = var.backup_password
}

# --------
resource "google_secret_manager_secret" "admin_token_hash" {
  secret_id = "admin_token_hash"
  replication {
    auto {}
  }
}
resource "google_secret_manager_secret_version" "admin_token_hash_val" {
  secret      = google_secret_manager_secret.admin_token_hash.id
  secret_data = var.admin_token_hash
}



