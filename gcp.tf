# Get the Default Compute Service Account
data "google_compute_default_service_account" "default" {}

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
      // Ephemeral public IP
    }
  }

  service_account {
    email  = data.google_compute_default_service_account.default.email
    scopes = ["cloud-platform"]
  }

  depends_on = [
    google_project_service.compute_api,
    google_project_service.secret_manager_api,

    google_secret_manager_secret_iam_member.vm_secret_access,
    cloudflare_zero_trust_tunnel_cloudflared.vault_tunnel,
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
  })
}

# -------- Enable GCP services
resource "google_project_service" "compute_api" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}
resource "google_project_service" "secret_manager_api" {
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}