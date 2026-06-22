# Get Cloudflare tunnel ID
data "cloudflare_zero_trust_tunnel_cloudflared_token" "vault_tunnel" {
  account_id = cloudflare_zero_trust_tunnel_cloudflared.vault_tunnel.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.vault_tunnel.id
}

# Allow SSH via IAP
resource "google_compute_firewall" "allow_ssh_iap" {
  name     = "vaultwarden-allow-ssh-iap"
  network  = "default"
  priority = 1000
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["vaultwarden-server"]
}

# Firewall rule to deny all inbound (ingress) traffic
resource "google_compute_firewall" "deny_all_ingress" {
  name     = "vaultwarden-deny-ingress"
  network  = "default"
  priority = 65534
  deny {
    protocol = "all"
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["vaultwarden-server"]
}

# Free Tier VM
resource "google_compute_instance" "vault_vm" {
  name         = "vaultwarden-server"
  machine_type = "e2-micro"
  zone         = var.gcp_zone

  tags = ["vaultwarden-server"] # for attaching firewall rules

  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
      size  = 30
      type  = "pd-standard"
    }
  }

  network_interface {
    network = "default"

    # trivy:ignore:AVD-GCP-0031
    access_config {
      # Ephemeral public IP
      # Justification: Utilizing an ephemeral IP for outbound Cloudflare Tunnel connectivity to avoid Cloud NAT costs.
      # All inbound ingress is blocked via the GCP firewall.
      network_tier = "STANDARD"
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
    google_storage_bucket_iam_member.vm_restore_script_viewer,
  ]

  # Docker startup execution
  metadata_startup_script = templatefile("${path.module}/scripts/instance_startup.sh.tftpl", {
    vaultwarden_server_container_hash         = var.vaultwarden_server_container_hash
    cloudflare_cloudflared_container_hash     = var.cloudflare_cloudflared_container_hash
    ttionya_vaultwarden_backup_container_hash = var.ttionya_vaultwarden_backup_container_hash
    cf_account_id                             = var.cf_account_id
    backup_bucket_name                        = cloudflare_r2_bucket.vault_backup_bucket.name
    backup_cron                               = var.vw_backup_cron
    backup_keep_days                          = var.vw_backup_keep_days
    gcp_project_id                            = var.gcp_project_id
    restore_script_bucket_name                = google_storage_bucket.restore_script_bucket.name
    restore_script_object_name                = google_storage_bucket_object.restore_backup_script.name
  })

  # Security features and monitoring
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
  metadata = {
    "enable-oslogin"            = "true"
    "google-monitoring-enabled" = "true"
    "google-logging-enabled"    = "true"
  }
}

# Bucket that holds the 'restore backup' script
resource "google_storage_bucket" "restore_script_bucket" {
  name                        = var.gcp_restore_script_bucket_name
  location                    = var.gcp_region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
}
# Upload the restore script to the bucket
resource "google_storage_bucket_object" "restore_backup_script" {
  name   = "restore_backup.sh"
  source = "${path.module}/scripts/restore_backup.sh"
  bucket = google_storage_bucket.restore_script_bucket.name
}
