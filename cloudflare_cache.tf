resource "cloudflare_ruleset" "vaultwarden_cache" {
  zone_id     = var.cf_zone_id
  name        = "Cache Vaultwarden Web Vault"
  description = "Offload static web vault assets to Cloudflare Edge"
  kind        = "zone"
  phase       = "http_request_cache_settings"


  rules = [{
    description = "Cache static UI files for 1 month"
    expression  = "(http.host eq \"${var.cf_subdomain}.${var.cf_domain}\" and starts_with(http.request.uri.path, \"/web-vault/\"))"
    action      = "set_cache_settings"
    enabled     = true

    # 'action_parameters' also requires an equals sign and an object
    action_parameters = {
      cache = true
      # Edge TTL (How long Cloudflare's servers keep the files)
      # 2592000 seconds = 30 days
      edge_ttl = {
        mode    = "override_origin"
        default = 2592000
      }
      # Browser TTL (How long your phone/computer keeps the files without asking Cloudflare)
      # 86400 seconds = 1 day
      browser_ttl = {
        mode    = "override_origin"
        default = 86400
      }
    }
  }]
}