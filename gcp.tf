# Get Cloudflare tunnel id
data "cloudflare_zero_trust_tunnel_cloudflared_token" "vault_tunnel" {
  account_id = cloudflare_zero_trust_tunnel_cloudflared.vault_tunnel.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.vault_tunnel.id
}

# Firewall deny all
resource "google_compute_firewall" "deny_all_ingress" {
  name    = "vaultwarden-deny-ingress"
  network = "default"
  deny {
    protocol = "all"
  }
  source_ranges = ["0.0.0.0/0"]
}

# Free Tier VM
resource "google_compute_instance" "vault_vm" {
  name         = "vaultwarden-server"
  machine_type = "e2-micro"
  zone         = var.gcp_zone

  tags = ["vaultwarden-server"]

  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
      size  = 30
      type  = "pd-standard"
    }
  }

  network_interface {
    network = "default"

    access_config {
      # Ephemeral public IP
    }
  }

  service_account {
    email  = google_service_account.vaultwarden_vm_sa.email
    scopes = ["cloud-platform"]
  }

  depends_on = [
    google_secret_manager_secret_iam_member.vm_secret_access,
    cloudflare_zero_trust_tunnel_cloudflared.vault_tunnel,

    google_secret_manager_secret_version.r2_key_val,
    google_secret_manager_secret_version.r2_key_id_val,
    google_secret_manager_secret_version.backup_pass_val,
    google_secret_manager_secret_version.admin_token_hash_val,
    google_secret_manager_secret_version.vault_tunnel_token_val,
  ]

  # Docker startup execution
  metadata_startup_script = templatefile("${path.module}/scripts/instance_startup.sh.tftpl", {
    vaultwarden_server_version = var.vaultwarden_server_version
    cloudflared_version        = var.cloudflare_cloudflared_version
    vaultwarden_backup_version = var.ttionya_vaultwarden_backup_version
    cf_account_id              = var.cf_account_id
    backup_bucket_name         = cloudflare_r2_bucket.vault_backup_bucket.name
    backup_chron               = var.vw_backup_cron
    backup_keep_days           = var.vw_backup_keep_days
    gcp_project_id             = var.gcp_project_id
    restore_script_bucket_name = google_storage_bucket.restore_script_bucket.name
    restore_script_object_name = google_storage_bucket_object.restore_backup_script.name
  })
}

# Bucket that holds the 'restore backup' script
resource "google_storage_bucket" "restore_script_bucket" {
  name                        = "vaultwarden-restore-backup-bucket"
  location                    = var.gcp_region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
}
# and we upload the script to the bucket
resource "google_storage_bucket_object" "restore_backup_script" {
  name   = "restore_backup.sh"
  source = "${path.module}/scripts/restore_backup.sh"
  bucket = google_storage_bucket.restore_script_bucket.name
}
