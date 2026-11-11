# The WAF rules of the zones that serve stamps, on the Cloudflare Free plan
# (10-roadmap.md section 13, phase 10 edge rules; ADR 0027). Cloudflare's free
# managed ruleset runs on every proxied name of every zone by default and isn't
# managed here. A zone that serves no stamp hostname gets no custom rule: its
# proxied names are sites on outside hosting, which may serve PHP. The rate
# limit covers every zone that serves a stamp or the public production of a
# site on Cloudflare Pages (ADR 0060), and a zone whose domain sets
# waf_rate_limit: true in catalog/domains.yaml, so the outside sites of a zone
# keep it while it has neither (07 section 2.1). waf_rate_limit: false turns it
# off for a zone.
#
# The Free plan allows 5 custom rules and 1 rate limiting rule per zone. Each
# phase has one entry-point ruleset per zone, so a rule added by hand in the
# dashboard makes the create fail; delete it there first.

locals {
  # The stamp hostnames of each zone in domains.
  waf_zones = {
    for z in distinct(compact([for h in values(local.hostnames) : h.zone])) :
    z => sort([for fqdn, h in local.hostnames : fqdn if h.zone == z])
  }

  # The zones that serve stamps or a public Pages production, and those whose
  # domain opts in, less those whose domain opts out.
  rate_limit_zones = setsubtract(
    toset(concat(
      keys(local.waf_zones),
      [for h in values(local.pages_hostnames) : h.zone if h.environment == "production" && !h.protected && h.zone != null],
      [for d in local.catalog.domains : d.name if try(d.waf_rate_limit, false)],
    )),
    [for d in local.catalog.domains : d.name if try(d.waf_rate_limit, null) == false],
  )
}

# Requests for paths no platform app serves: PHP, WordPress and leaked
# repository or settings files, which scanners try on every host. Blocked at
# the edge, they never wake a replica. /.well-known/ stays open.
resource "cloudflare_ruleset" "waf_custom" {
  for_each = local.waf_zones
  zone_id  = cloudflare_zone.this[each.key].id
  name     = "waf-custom"
  kind     = "zone"
  phase    = "http_request_firewall_custom"

  rules = [
    {
      ref         = "block-probes"
      description = "Block scanner paths on stamp hostnames"
      expression = join(" and ", [
        "(http.host in {${join(" ", [for h in each.value : "\"${h}\""])}})",
        join("", [
          "(ends_with(lower(http.request.uri.path), \".php\")",
          " or starts_with(lower(http.request.uri.path), \"/wp-\")",
          " or http.request.uri.path contains \"/.env\"",
          " or http.request.uri.path contains \"/.git\"",
          " or http.request.uri.path contains \"/.aws\")",
        ]),
      ])
      action = "block"
    },
  ]
}

# One client making more than 100 requests in 10 seconds through one Cloudflare
# data centre is blocked for 10 seconds, which stops a flood from scaling the
# stamps out. A page of the corporate site loads fewer than 10 files. The Free plan
# fixes the period and the timeout at 10 seconds and allows only the path and
# verified bot fields, so the rule covers every proxied name of the zone, not
# only the stamp hostnames. That is why a zone can keep it without stamps
# (waf_rate_limit in catalog/domains.yaml). Verified bots, search engines among
# them, are left out.
resource "cloudflare_ruleset" "waf_rate_limit" {
  for_each = local.rate_limit_zones
  zone_id  = cloudflare_zone.this[each.key].id
  name     = "waf-rate-limit"
  kind     = "zone"
  phase    = "http_ratelimit"

  rules = [
    {
      ref         = "rate-limit-per-ip"
      description = "100 requests in 10 seconds per client"
      expression  = "(http.request.uri.path contains \"/\") and not cf.client.bot"
      action      = "block"
      ratelimit = {
        characteristics     = ["cf.colo.id", "ip.src"]
        period              = 10
        requests_per_period = 100
        mitigation_timeout  = 10
      }
    },
  ]
}
