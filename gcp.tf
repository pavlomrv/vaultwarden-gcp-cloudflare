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
  zone         = var.zone

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
  metadata_startup_script = <<-EOT
    #!/bin/bash
    mkdir -p /var/vaultwarden/data
    docker network create vaultwarden-net

    # Launch Vaultwarden
    docker run -d \
      --name vaultwarden \
      --restart always \
      --network vaultwarden-net \
      -v /var/vaultwarden/data:/data \
      -e SIGNUPS_ALLOWED=false \
      -e WEBSOCKET_ENABLED=true \
      -e ICON_SERVICE=internal \
      -e ICON_CACHE_TTL=2592000 \
      -e ADMIN_TOKEN=$(gcloud secrets versions access latest --secret="admin_token_hash") \
      vaultwarden/server:${var.vaultwarden_server_version}

    sleep 10

    # Launch Cloudflare Tunnel (Connects out to CF, routes to vaultwarden container)
    docker run -d \
      --name cloudflared \
      --restart always \
      --network vaultwarden-net \
      cloudflare/cloudflared:${var.cloudflare_cloudflared_version} tunnel --no-autoupdate run --token $(gcloud secrets versions access latest --secret="vault_tunnel_token")

    # Launch the Offsite Backup Engine
    docker run -d \
      --name vaultwarden_backup \
      --restart always \
      --network vaultwarden-net \
      -v /var/vaultwarden/data:/data \
      -e DATA_DIR=/data \
      -e ZIP_TYPE=zip \
      -e CRON_EXPRESSION="0 2 * * *" \
      -e BACKUP_KEEP_DAYS=30 \
      -e BACKUP_ENCRYPTION_KEY=$(gcloud secrets versions access latest --secret="backup_pass") \
      -e STORAGE_TYPE=s3 \
      -e AWS_ACCESS_KEY_ID=$(gcloud secrets versions access latest --secret="r2_key_id") \
      -e AWS_SECRET_ACCESS_KEY=$(gcloud secrets versions access latest --secret="r2_key") \
      -e S3_ENDPOINT="https://${var.cf_account_id}.r2.cloudflarestorage.com" \
      -e S3_BUCKET=${cloudflare_r2_bucket.vault_backup_bucket.name} \
      ttionya/vaultwarden-backup:${var.ttionya_vaultwarden_backup_version}

  EOT
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