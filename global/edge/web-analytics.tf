# Cloudflare Web Analytics for the production of each site whose environment
# sets web_analytics: true in catalog/products.yaml (ADR 0060): cookieless
# visit counts and the Core Web Vitals of real visitors, free. auto_install is
# off, so the edge injects nothing: the site renders the beacon itself with the
# token below (tl-template-website docs/analytics.md), and its CSP and privacy
# policy say so. The token is public; it is in every page.

locals {
  web_analytics = merge([
    for repo, p in local.pages : {
      for e in p.environments : e.hostname => { repo = repo } if try(e.web_analytics, false) && e.name == "production"
    }
  ]...)
}

resource "cloudflare_web_analytics_site" "this" {
  for_each     = local.web_analytics
  account_id   = var.cloudflare_account_id
  host         = each.key
  auto_install = false
}

output "web_analytics_tokens" {
  value = { for host, s in cloudflare_web_analytics_site.this : host => s.site_token }
}
