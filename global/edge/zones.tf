# One Cloudflare zone per entry of domains in catalog/tenants.yaml, in SSL mode
# Full (strict) (ADR 0027). Its nameservers, and no others, are listed at the
# registrar by hand (N11; 11-onboarding.md section 7).

locals {
  catalog = yamldecode(file("${path.module}/../../catalog/tenants.yaml"))
  domains = { for d in local.catalog.domains : d.name => d }
}

resource "cloudflare_zone" "this" {
  for_each = local.domains
  account  = { id = var.cloudflare_account_id }
  name     = each.key
  type     = "full"
}

resource "cloudflare_zone_setting" "ssl" {
  for_each   = cloudflare_zone.this
  zone_id    = each.value.id
  setting_id = "ssl"
  value      = "strict"
}

# A new zone's nameservers are known only after apply, so they are read from
# the apply log or the Cloudflare dashboard, not from the plan.
output "name_servers" {
  value = { for name, zone in cloudflare_zone.this : name => zone.name_servers }
}
