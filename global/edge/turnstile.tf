# A Turnstile widget for each site environment that sets turnstile: true in
# catalog/products.yaml (ADR 0060): Cloudflare's free, cookieless challenge for
# a form. It does nothing on its own. It acts only where a page of the site
# embeds it with the site key (tl-template-website docs/forms.md) and the form's
# endpoint checks the token with the secret (D-14). A site without a form sets
# nothing and gets no widget.

locals {
  turnstile = merge([
    for repo, p in local.pages : {
      for e in p.environments : "${repo}/${e.name}" => { hostname = e.hostname } if try(e.turnstile, false)
    }
  ]...)
}

resource "cloudflare_turnstile_widget" "this" {
  for_each   = local.turnstile
  account_id = var.cloudflare_account_id
  name       = replace(each.key, "/", "-")
  domains    = [each.value.hostname]
  mode       = "managed"
}

# The site key is public and goes into the site's settings.
output "turnstile_site_keys" {
  value = { for k, w in cloudflare_turnstile_widget.this : k => w.sitekey }
}

# The secret goes only to the form endpoint, never into a site.
output "turnstile_secrets" {
  value     = { for k, w in cloudflare_turnstile_widget.this : k => w.secret }
  sensitive = true
}
