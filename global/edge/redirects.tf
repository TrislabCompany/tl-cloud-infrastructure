# The permanent host redirects of each domain in catalog/tenants.yaml
# (domains[].redirects; 07-catalog-and-ipam.md section 2.1.1, ADR 0057): one
# Single Redirects ruleset per zone, run at the edge before any origin. The
# Free plan allows 10 such rules per zone. A source host must be a proxied
# record in records/<zone>/, because only proxied names pass the edge.

locals {
  redirect_zones = {
    for d in local.catalog.domains : d.name => d.redirects
    if length(try(d.redirects, [])) > 0
  }

  # The names of the proxied records in records/<zone>/, by zone.
  proxied_names = {
    for z in keys(local.domains) : z => [
      for r in values(local.records) : r.name if r.zone == z && try(r.proxied, false)
    ]
  }
}

resource "cloudflare_ruleset" "redirects" {
  for_each = local.redirect_zones
  zone_id  = cloudflare_zone.this[each.key].id
  name     = "redirects"
  kind     = "zone"
  phase    = "http_request_dynamic_redirect"

  rules = [
    for r in each.value : {
      ref         = "redirect-${replace(r.from, ".", "-")}"
      description = "${r.from} to ${r.to}"
      expression  = "(http.host eq \"${r.from}\")"
      action      = "redirect"
      action_parameters = {
        from_value = {
          status_code           = 301
          preserve_query_string = true
          target_url = {
            expression = "concat(\"https://${r.to}\", http.request.uri.path)"
          }
        }
      }
    }
  ]

  lifecycle {
    precondition {
      condition     = alltrue([for r in each.value : contains(local.proxied_names[each.key], r.from)])
      error_message = "Every redirect source of ${each.key} needs a proxied record in records/${each.key}/ (ADR 0057)."
    }
    precondition {
      condition     = length(each.value) <= 10
      error_message = "The Free plan allows 10 Single Redirects rules per zone; ${each.key} has ${length(each.value)}."
    }
  }
}
