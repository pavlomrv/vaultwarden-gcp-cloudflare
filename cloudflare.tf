
# Route traffic from the domain to the Tunnel
resource "cloudflare_dns_record" "vault_dns" {
  zone_id = var.cf_zone_id
  name    = var.cf_subdomain # Creates a subdomain, like 'vault.domain.com'
  content = "${cloudflare_zero_trust_tunnel_cloudflared.vault_tunnel.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true # Keeps your GCP IP hidden and enables DDoS protection
  ttl     = 1
}

# Generate a secret for the tunnel
resource "random_id" "tunnel_secret" {
  byte_length = 35
}

# Create the Cloudflare Tunnel
resource "cloudflare_zero_trust_tunnel_cloudflared" "vault_tunnel" {
  account_id    = var.cf_account_id
  name          = var.cf_tunnel_name
  tunnel_secret = random_id.tunnel_secret.b64_std
  config_src    = "cloudflare"
}

# Configure Tunnel Routing (Points to the internal Docker container)
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "vault_tunnel_config" {
  account_id = var.cf_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.vault_tunnel.id

  config = {
    ingress = [
      {
        hostname = "${var.cf_subdomain}.${var.cf_domain}" # e.g. 'vault.domain.com'
        service  = "http://vaultwarden:80"                # Routes to vaultwarden container

        origin_request = {
          connect_timeout          = 30
          disable_chunked_encoding = false
          http2_origin             = false
          keep_alive_connections   = 100
          keep_alive_timeout       = 90
        }
      },
      {
        service = "http_status:404" # Catch-all fallback
      }
    ]
  }
}

# Create the Cloudflare R2 Bucket for backups
resource "cloudflare_r2_bucket" "vault_backup_bucket" {
  account_id = var.cf_account_id
  name       = var.cf_r2_backup_bucket_name
  location   = var.cf_r2_location
}

# Enforce SSL Mode to "Full"
resource "cloudflare_zone_setting" "ssl_settings" {
  zone_id    = var.cf_zone_id
  setting_id = "ssl"
  value      = "strict"
}

# Enforce "Always Use HTTPS" (Automatic 301 redirects)
resource "cloudflare_zone_setting" "always_use_https_setting" {
  zone_id    = var.cf_zone_id
  setting_id = "always_use_https"
  value      = "on"
}

# Enforce a Minimum TLS version of 1.2
resource "cloudflare_zone_setting" "min_tls_setting" {
  zone_id    = var.cf_zone_id
  setting_id = "min_tls_version"
  value      = "1.2"
}
