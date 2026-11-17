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

# Cloudflare attaches a Custom Domain only to a Worker that has a deployment,
# so a new Worker first gets a placeholder that answers 503 until wrangler
# deploys its code. The placeholder is created once and then forgotten
# (removed blocks), never kept: Cloudflare keeps only recent deployments, and
# the provider would recreate a forgotten one over the real code. A new worker
# takes two applies: one with these resources, one with the removed blocks.
locals {
  worker_placeholder = <<-EOT
    export default {
      fetch() {
        return Response.json({ ok: false, version: "none", issues: ["no version deployed yet"] }, { status: 503 });
      },
    };
  EOT
}

resource "cloudflare_worker_version" "placeholder" {
  for_each           = local.worker_environments
  account_id         = var.cloudflare_account_id
  worker_id          = cloudflare_worker.this[each.key].id
  compatibility_date = "2026-10-26"
  main_module        = "index.js"
  modules = [{
    name           = "index.js"
    content_type   = "application/javascript+module"
    content_base64 = base64encode(local.worker_placeholder)
  }]
}

resource "cloudflare_workers_deployment" "placeholder" {
  for_each    = local.worker_environments
  account_id  = var.cloudflare_account_id
  script_name = cloudflare_worker.this[each.key].name
  strategy    = "percentage"
  versions = [{
    percentage = 100
    version_id = cloudflare_worker_version.placeholder[each.key].id
  }]
}

resource "cloudflare_workers_custom_domain" "this" {
  for_each   = { for k, w in local.worker_environments : k => w if w.zone != null }
  account_id = var.cloudflare_account_id
  zone_id    = cloudflare_zone.this[each.value.zone].id
  hostname   = each.value.hostname
  service    = cloudflare_worker.this[each.key].name

  depends_on = [cloudflare_workers_deployment.placeholder]

  # A Custom Domain creates the hostname's DNS record, so no record of
  # global/edge/records/ and no site may have its name.
  lifecycle {
    precondition {
      condition     = length([for r in local.records : r if r.name == each.value.hostname]) == 0 && !contains(keys(local.pages_hostnames), each.value.hostname)
      error_message = "${each.value.hostname} is a hostname of a worker in catalog/products.yaml, so global/edge/records/ must not hold a record for it and no site may use it. Delete the record, or the environment."
    }
  }
}
