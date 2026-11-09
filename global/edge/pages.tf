# The sites on Cloudflare Pages, from pages in catalog/repos.yaml: one Direct
# Upload project per repository, deployed by the repository's own workflows
# with wrangler. Each environment is a Pages branch of the same name, served
# on its hostname: production is the project's production branch, and dev or
# staging are branch aliases, <branch>.<project>.pages.dev. The hostnames get
# Access applications in zero-trust.tf, and so do the project's pages.dev
# names, which serve the same files.

locals {
  repos_catalog = yamldecode(file("${path.module}/../../catalog/repos.yaml"))

  # The owner of a repository's Access policy: its customer, or trislab.
  repo_owners = { for r in local.repos_catalog.repos : r.name => try(r.customer, "trislab") }

  pages = {
    for p in try(local.repos_catalog.pages, []) : p.repo => merge(p, { owner = lookup(local.repo_owners, p.repo, "trislab") })
  }

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
}
