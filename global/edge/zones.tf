# One Cloudflare zone per entry of domains in catalog/domains.yaml, in SSL mode
# Full (strict) (ADR 0027). Its nameservers, and no others, are listed at the
# registrar by hand (N11; 11-onboarding.md section 7).

locals {
  catalog = yamldecode(file("${path.module}/../../catalog/domains.yaml"))
  domains = { for d in local.catalog.domains : d.name => d }

  # Tenants and their products (catalog/products.yaml), read once for pages.tf
  # and records.tf.
  tenants = yamldecode(file("${path.module}/../../catalog/products.yaml")).tenants
}

resource "cloudflare_zone" "this" {
  for_each = local.domains
  account  = { id = var.cloudflare_account_id }
  name     = each.key
  type     = "full"

  # A domain with search_console keeps the TXT record that verifies its Google
  # Search Console property (07 section 2.1.2): the key it names is a
  # google-site-verification record in records/<domain>/<domain>.yaml, so a
  # change to the records can't drop it unnoticed.
  lifecycle {
    precondition {
      condition = try(each.value.search_console, null) == null || can(regex(
        "^google-site-verification=",
        local.records["${each.key}/${each.key}/${each.value.search_console.verification}"].type == "TXT" ? local.records["${each.key}/${each.key}/${each.value.search_console.verification}"].content : ""
      ))
      error_message = "catalog/domains.yaml: the search_console verification of ${each.key} is not a google-site-verification TXT record in global/edge/records/${each.key}/${each.key}.yaml (07 section 2.1.2)."
    }
  }
}

resource "cloudflare_zone_setting" "ssl" {
  for_each   = cloudflare_zone.this
  zone_id    = each.value.id
  setting_id = "ssl"
  value      = "strict"
}

# Proxied names answer HTTP with a redirect to HTTPS, and only over TLS 1.2 or
# later. DNS-only names don't pass Cloudflare, so neither applies to them.
resource "cloudflare_zone_setting" "always_use_https" {
  for_each   = cloudflare_zone.this
  zone_id    = each.value.id
  setting_id = "always_use_https"
  value      = "on"
}

resource "cloudflare_zone_setting" "min_tls_version" {
  for_each   = cloudflare_zone.this
  zone_id    = each.value.id
  setting_id = "min_tls_version"
  value      = "1.2"
}

# A new zone's nameservers are known only after apply, so they are read from
# the apply log or the Cloudflare dashboard, not from the plan.
output "name_servers" {
  value = { for name, zone in cloudflare_zone.this : name => zone.name_servers }
}
