# The sites on Cloudflare Pages, the products with environments in
# catalog/products.yaml: one Direct
# Upload project per repository, deployed by the repository's own workflows
# with wrangler. Each environment is a Pages branch of the same name, served
# on its hostname: production is the project's production branch, and dev or
# staging are branch aliases, <branch>.<project>.pages.dev. The hostnames get
# Access applications in zero-trust.tf, and so do the project's pages.dev
# names, which serve the same files.

locals {
  # owner is the tenant's code, as for the hostnames of stamps (records.tf): it
  # names the Access policy, which admits grp-cust-<code>-admins. trislab, the
  # tenant without a code, is trislab.
  pages = merge([
    for t in local.tenants : {
      for p in t.products : p.repo => { repo = p.repo, environments = p.environments, owner = try(t.code, "trislab") }
      if try(p.environments, null) != null
    }
  ]...)

  # By FQDN, with its zone, as for the hostnames of stamps (records.tf).
  pages_hostnames = merge([
    for repo, p in local.pages : {
      for e in p.environments : e.hostname => {
        repo        = repo
        environment = e.name
        owner       = p.owner
        protected   = try(e.access, "protected") != "public"
        zone        = try([for d in [e.hostname, trimprefix(e.hostname, "${split(".", e.hostname)[0]}.")] : d if contains(keys(local.domains), d)][0], null)
      }
    }
  ]...)
}

resource "cloudflare_pages_project" "this" {
  for_each          = local.pages
  account_id        = var.cloudflare_account_id
  name              = each.key
  production_branch = "production"
}

# Cloudflare adds a custom domain to the production branch; the record below
# points a dev or staging hostname at its branch alias instead.
resource "cloudflare_pages_domain" "this" {
  for_each     = local.pages_hostnames
  account_id   = var.cloudflare_account_id
  project_name = cloudflare_pages_project.this[each.value.repo].name
  name         = each.key
}

# subdomain is <project>.pages.dev, or with a suffix Cloudflare adds when the
# name is taken on pages.dev.
resource "cloudflare_dns_record" "pages" {
  for_each = { for fqdn, h in local.pages_hostnames : fqdn => h if h.zone != null }
  zone_id  = cloudflare_zone.this[each.value.zone].id
  name     = each.key
  type     = "CNAME"
  content  = each.value.environment == "production" ? cloudflare_pages_project.this[each.value.repo].subdomain : "${each.value.environment}.${cloudflare_pages_project.this[each.value.repo].subdomain}"
  proxied  = true
  ttl      = 1

  depends_on = [cloudflare_pages_domain.this]

  # A hostname of a site is a CNAME to Pages, so no A, AAAA or CNAME record of
  # global/edge/records/ may have its name. MX, TXT and the like may: they
  # share the apex with it.
  lifecycle {
    precondition {
      condition     = length([for r in local.records : r if r.name == each.key && contains(["A", "AAAA", "CNAME"], r.type)]) == 0
      error_message = "${each.key} is a hostname of a site on Cloudflare Pages in catalog/products.yaml, so global/edge/records/ must not also hold an A, AAAA or CNAME record for it. Delete the record, or the environment."
    }
  }
}

# trislab.com moved from the hosting (records/trislab.com) to the production of
# trislab-website-corporate-site. moved updates the record in place, so no apply
# creates the name while its old record still exists.
moved {
  from = cloudflare_dns_record.this["trislab.com/trislab.com/apex"]
  to   = cloudflare_dns_record.pages["trislab.com"]
}
