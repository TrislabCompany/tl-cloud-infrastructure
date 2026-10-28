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
