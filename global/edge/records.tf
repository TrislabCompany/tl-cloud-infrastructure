# The DNS records of each zone, one file per domain under records/<zone>/. A
# record's address is <zone>/<file>/<key>, so a key only has to be unique in
# its file. The records of stamps come from catalog/tenants.yaml.
#
# A name is proxied (proxied: true) when it serves only HTTPS on ports
# Cloudflare passes and the hosting has a valid certificate for it, which Full
# (strict) needs. Mail, FTP, WebDisk and CalDAV/CardDAV use ports Cloudflare
# doesn't pass, so they, and every name an MX, SRV or DNS-only CNAME points at,
# stay DNS-only.

locals {
  records = merge([
    for f in fileset("${path.module}/records", "*/*.yaml") : {
      for key, r in yamldecode(file("${path.module}/records/${f}")) :
      "${trimsuffix(f, ".yaml")}/${key}" => merge(r, { zone = dirname(f) })
    }
  ]...)
}

resource "cloudflare_dns_record" "this" {
  for_each = local.records
  zone_id  = cloudflare_zone.this[each.value.zone].id
  name     = each.value.name
  type     = each.value.type
  priority = try(each.value.priority, null)
  proxied  = try(each.value.proxied, false)

  # A proxied record's TTL is always 1, automatic.
  ttl = try(each.value.proxied, false) ? 1 : 3600

  # An SRV record has no content: its weight, port and target are in data.
  data = each.value.type == "SRV" ? merge(each.value.data, { priority = each.value.priority }) : null

  # Cloudflare stores TXT content quoted, one string of at most 255 characters
  # each, so it is written that way to keep the plan clean.
  content = each.value.type == "SRV" ? null : each.value.type == "TXT" ? join(" ", formatlist("\"%s\"", regexall(".{1,255}", each.value.content))) : each.value.content
}

# ---- The hostnames of stamps -------------------------------------------------
# Each hostname in catalog/tenants.yaml, and each derived hostname: the default
# hostname with -<app> added to its first label, for every external app of a
# stamp.yaml other than the first (07-catalog-and-ipam.md section 3.1).
# certificates.tf and zero-trust.tf read them too.

locals {
  owners = yamldecode(file("${path.module}/../../catalog/owners.yaml")).owners

  # stamp.yaml by stamp folder, <lz>/<folder>.
  stamp_files = {
    for f in fileset("${path.module}/../../stamps", "*/*/stamp.yaml") :
    trimsuffix(f, "/stamp.yaml") => yamldecode(file("${path.module}/../../stamps/${f}"))
  }

  stamps = {
    for folder, s in local.stamp_files : folder => {
      lz = s.lz

      # <owner-code>-<product-code>-<environment>[-<number>]
      # (06-stamp-templates.md section 3.2).
      code = join("-", compact([
        startswith(s.lz, "products-") ? "shr" : startswith(s.lz, "cust-") ? split("-", s.lz)[1] : "",
        one([for o in local.owners : o.code if o.slug == s.product]),
        s.environment,
        try(tostring(s.number), ""),
      ]))

      # <environment>-<product>[-<customer>][-<number>].trislab.com
      default = "${join("-", compact([
        s.environment,
        s.product,
        startswith(s.lz, "cust-") ? one([for o in local.owners : o.slug if o.code == split("-", s.lz)[1]]) : "",
        try(tostring(s.number), ""),
      ]))}.trislab.com"

      external = [for a in s.apps : a.name if a.ingress == "external"]
    }
  }

  stamp_hostnames = concat(
    flatten([
      for t in local.catalog.tenants : [
        for h in try(t.hostnames, []) : { fqdn = h.fqdn, app = h.app, stamp = t.stamp }
      ]
    ]),
    flatten([
      for folder, s in local.stamps : [
        for app in slice(s.external, min(1, length(s.external)), length(s.external)) : {
          fqdn  = replace(s.default, "/^([^.]+)/", "$1-${app}")
          app   = app
          stamp = folder
        }
      ]
    ]),
  )

  # By FQDN, with its zone: a hostname is a domain's root or one label below
  # it (07-catalog-and-ipam.md sections 3.1 and 3.2). A sandbox landing zone's
  # owner is trislab, or the customer code of cust-<code>-* (section 3.3).
  hostnames = {
    for h in local.stamp_hostnames : h.fqdn => merge(h, {
      lz      = local.stamps[h.stamp].lz
      code    = local.stamps[h.stamp].code
      sandbox = strcontains(local.stamps[h.stamp].lz, "-sandbox-")
      owner   = startswith(local.stamps[h.stamp].lz, "cust-") ? split("-", local.stamps[h.stamp].lz)[1] : "trislab"
      zone    = try([for d in [h.fqdn, trimprefix(h.fqdn, "${split(".", h.fqdn)[0]}.")] : d if contains(keys(local.domains), d)][0], null)
    })
  }
}

# ---- Records of stamp hostnames ------------------------------------------------
# One Azure Resource Graph query for the environments cae-<stamp> of every
# stamp, through Edge stamp reader. A hostname gets its records once its
# stamp's environment exists (ADR 0027, Technical details, Lookup).

locals {
  stamp_codes = toset([for s in local.stamps : s.code])
}

data "azapi_resource_action" "environments" {
  count       = length(local.stamp_codes) > 0 ? 1 : 0
  type        = "Microsoft.ResourceGraph@2022-10-01"
  resource_id = "/providers/Microsoft.ResourceGraph"
  action      = "resources"
  method      = "POST"
  body = {
    query = "resources | where type =~ 'microsoft.app/managedenvironments' and name in~ (${join(", ", [for c in local.stamp_codes : "'cae-${c}'"])}) | project name, defaultDomain = tostring(properties.defaultDomain), verificationId = tostring(properties.customDomainConfiguration.customDomainVerificationId)"
  }
  response_export_values = ["data"]
}

locals {
  environments = {
    for e in try(data.azapi_resource_action.environments[0].output.data, []) : e.name => e
  }

  # The hostnames in a zone of domains whose stamp has an environment.
  # Hostnames in external_domains become custom hostnames instead (ADR 0037).
  live_hostnames = {
    for fqdn, h in local.hostnames : fqdn => merge(h, { environment = local.environments["cae-${h.code}"] })
    if h.zone != null && contains(keys(local.environments), "cae-${h.code}")
  }
}

resource "cloudflare_dns_record" "stamp" {
  for_each = local.live_hostnames
  zone_id  = cloudflare_zone.this[each.value.zone].id
  name     = each.key
  type     = "CNAME"
  content  = "ca-${each.value.code}-${each.value.app}.${each.value.environment.defaultDomain}"
  proxied  = true
  ttl      = 1
}

resource "cloudflare_dns_record" "asuid" {
  for_each = local.live_hostnames
  zone_id  = cloudflare_zone.this[each.value.zone].id
  name     = "asuid.${each.key}"
  type     = "TXT"
  content  = "\"${each.value.environment.verificationId}\""
  proxied  = false
  ttl      = 3600
}
