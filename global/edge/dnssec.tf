# DNSSEC on the zones whose domain sets dnssec: true in catalog/domains.yaml
# (ADR 0060). Cloudflare signs the zone; resolvers trust the signatures only
# once the zone's DS record is at the registrar, which a person enters by hand,
# like the nameservers (N11; 11-onboarding.md section 7). Until then the status
# stays pending and nothing changes for visitors.
#
# Turning it off, or moving the domain away from Cloudflare, goes the other way
# round: first delete the DS record at the registrar and wait two days, then set
# dnssec: false. In the wrong order the domain stops resolving.

resource "cloudflare_zone_dnssec" "this" {
  for_each = { for name, d in local.domains : name => d if try(d.dnssec, false) }
  zone_id  = cloudflare_zone.this[each.key].id
  status   = "active"

  # Cloudflare reports "pending" until the DS record is at the registrar; asking
  # for "active" again would show as a change on every plan and drift check.
  lifecycle {
    ignore_changes = [status]
  }
}

# What the registrar asks for: the DS record, or its parts (key tag, algorithm
# 13, digest type 2 and the digest). Some registrars ask for the DNSKEY (flags
# 257, protocol 3, algorithm 13 and the public key) instead. None is secret.
output "ds_records" {
  value = {
    for name, z in cloudflare_zone_dnssec.this : name => {
      ds          = z.ds
      key_tag     = z.key_tag
      algorithm   = z.algorithm
      digest_type = z.digest_type
      digest      = z.digest
      flags       = z.flags
      public_key  = z.public_key
    }
  }
}
