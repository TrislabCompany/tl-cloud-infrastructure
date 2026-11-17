# The workers of catalog/products.yaml with environments (D-33): shared
# services on Cloudflare Workers, such as the form handler of the sites. For
# each environment this root creates the Worker, named
# <environment>-<product>-<tenant>, and its hostname as a Workers Custom
# Domain, which brings its own proxied DNS record and certificate. The code is
# deployed by the repository's own workflows with wrangler, into the Worker of
# the same name, as a site deploys into its Pages project (global/github
# workers.tf). A worker's hostname is always public: browsers post to it from
# the sites, so it gets no Access application.

locals {
  # The templates of a worker: none until tl-template-worker exists (policy/catalog.rego).
  worker_templates = ["none", "tl-template-worker"]

  workers = merge([
    for t in local.tenants : {
      for p in t.products : p.repo => { tenant = t.slug, product = p.slug, environments = p.environments }
      if try(p.environments, null) != null && contains(local.worker_templates, p.template)
    }
  ]...)

  # By <repo>/<environment>, with the hostname's zone, as for the sites (pages.tf).
  worker_environments = merge([
    for repo, w in local.workers : {
      for e in w.environments : "${repo}/${e.name}" => {
        name     = "${e.name}-${w.product}-${w.tenant}"
        hostname = e.hostname
        zone     = try([for d in [e.hostname, trimprefix(e.hostname, "${split(".", e.hostname)[0]}.")] : d if contains(keys(local.domains), d)][0], null)
      }
    }
  ]...)
}

# The Worker without code: wrangler deploys its versions. The settings match the
# repository's wrangler.toml: logs on, and no workers.dev name.
resource "cloudflare_worker" "this" {
  for_each   = local.worker_environments
  account_id = var.cloudflare_account_id
  name       = each.value.name

  observability = { enabled = true }
  subdomain     = { enabled = false, previews_enabled = false }
}

# Cloudflare attaches a Custom Domain only to a Worker that has a deployment.
# Each Worker got a placeholder version and deployment, answering 503 until
# wrangler deployed its code, and they are now forgotten, not destroyed: the
# provider would recreate a deployment that Cloudflare no longer lists over the
# real code. A new worker therefore takes two PRs: one that adds the placeholder
# back for it (as in the commit "Give each new Worker a placeholder deployment,
# so its Custom Domain can attach"), applied, then one that forgets it again.
removed {
  from = cloudflare_workers_deployment.placeholder
  lifecycle {
    destroy = false
  }
}

removed {
  from = cloudflare_worker_version.placeholder
  lifecycle {
    destroy = false
  }
}

resource "cloudflare_workers_custom_domain" "this" {
  for_each   = { for k, w in local.worker_environments : k => w if w.zone != null }
  account_id = var.cloudflare_account_id
  zone_id    = cloudflare_zone.this[each.value.zone].id
  hostname   = each.value.hostname
  service    = cloudflare_worker.this[each.key].name

  # A Custom Domain creates the hostname's DNS record, so no record of
  # global/edge/records/ and no site may have its name.
  lifecycle {
    precondition {
      condition     = length([for r in local.records : r if r.name == each.value.hostname]) == 0 && !contains(keys(local.pages_hostnames), each.value.hostname)
      error_message = "${each.value.hostname} is a hostname of a worker in catalog/products.yaml, so global/edge/records/ must not hold a record for it and no site may use it. Delete the record, or the environment."
    }
  }
}
