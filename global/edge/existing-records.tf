# The records trislab.com held at domenca.com before Cloudflare, copied as they
# were and not proxied, so the delegation changes nothing that runs today
# (10-roadmap.md section 8, PR 1). They point at the hosting 212.44.101.122
# and at Google Workspace for mail. When a site moves to the platform, its
# record changes here; the records of stamps come from catalog/tenants.yaml.

locals {
  hosting = "212.44.101.122"

  existing_records = {
    # The corporate site and the hosting.
    "apex"   = { name = "trislab.com", type = "A", content = local.hosting }
    "www"    = { name = "www.trislab.com", type = "CNAME", content = "trislab.com" }
    "mail"   = { name = "mail.trislab.com", type = "A", content = local.hosting }
    "ftp"    = { name = "ftp.trislab.com", type = "A", content = local.hosting }
    "cpanel" = { name = "cpanel.trislab.com", type = "A", content = local.hosting }

    # Mail: Google Workspace, and Microsoft's domain verification.
    "mx-aspmx"     = { name = "trislab.com", type = "MX", priority = 1, content = "aspmx.l.google.com" }
    "mx-alt1"      = { name = "trislab.com", type = "MX", priority = 5, content = "alt1.aspmx.l.google.com" }
    "mx-alt2"      = { name = "trislab.com", type = "MX", priority = 5, content = "alt2.aspmx.l.google.com" }
    "mx-alt3"      = { name = "trislab.com", type = "MX", priority = 10, content = "alt3.aspmx.l.google.com" }
    "mx-alt4"      = { name = "trislab.com", type = "MX", priority = 10, content = "alt4.aspmx.l.google.com" }
    "mx-microsoft" = { name = "trislab.com", type = "MX", priority = 32767, content = "ms10140753.msv1.invalid" }
    "spf"          = { name = "trislab.com", type = "TXT", content = "v=spf1 ip4:212.44.113.26 +a +mx +ip4:212.44.101.122 +include:_spf.controlpanel.si ~all" }
    "google"       = { name = "trislab.com", type = "TXT", content = "google-site-verification=QMOfBUlTpiaIN6yJyECqbzYPp6LNiOrFqS8T1Ly3ju0" }
    "dmarc"        = { name = "_dmarc.trislab.com", type = "TXT", content = "v=DMARC1; p=none" }
    # DKIM of the hosting's mail, sent by the sites' forms.
    "dkim-default" = { name = "default._domainkey.trislab.com", type = "TXT", content = "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvHyWGLqkowbJ/YTKaJlYvrp6/nAnCP9pXXymDL3Ei222MTqxmLeeiJb8WQoBj2G95UBCznwo5aROV6Tz5hxCtkDuHreo83fcReQ2eAcRwZdU0fZ+YmLdr042HG21r00eNjGX2kRrd0UzLYLBST3M+OTZtaUXoWSJk76OdS5BLzl9QqRAzoUcmBnHactwyVwmOHkii4lfTomc744LgfFDQh0K35+QLunnevZnj/UP44WNzRfWcVCFKlrijXem40OsCkM234ZkVnebdWbm8xmyh6IrWap5ciskU1Wxe/LuJbt6AMOhkZDJbDuMaLx0mAYZr8f7wj6nQI4bfPfv4gH+xQIDAQAB;" }

    # Resend, through Amazon SES.
    "dkim-resend" = { name = "resend._domainkey.trislab.com", type = "TXT", content = "p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC1igfSIt1T9K02kM+8rLlOEJaLhE9bVco9CUlGUYf6Nd30SHLAwQr5jhw501aTjn7LKrLwFVPytre63NuRZFRZAo8rgkpTdHbEPjoyXmsKzqY3SAWp7sSpZlscynyJ63y5SqYFgwHS+0iwMHwZoTD/Sb2YsW3upKhfdQDOdiwNUwIDAQAB" }
    "send-mx"     = { name = "send.trislab.com", type = "MX", priority = 10, content = "feedback-smtp.eu-west-1.amazonses.com" }
    "send-spf"    = { name = "send.trislab.com", type = "TXT", content = "v=spf1 include:amazonses.com ~all" }

    # Client sites on the hosting.
    "astragroup"             = { name = "astragroup.trislab.com", type = "A", content = local.hosting }
    "www-astragroup"         = { name = "www.astragroup.trislab.com", type = "A", content = local.hosting }
    "dragonja-si"            = { name = "dragonja.si.trislab.com", type = "A", content = local.hosting }
    "www-dragonja-si"        = { name = "www.dragonja.si.trislab.com", type = "A", content = local.hosting }
    "ldistragracisce-si"     = { name = "ldistragracisce.si.trislab.com", type = "A", content = local.hosting }
    "www-ldistragracisce-si" = { name = "www.ldistragracisce.si.trislab.com", type = "A", content = local.hosting }
    "spds-si"                = { name = "spds.si.trislab.com", type = "A", content = local.hosting }
    "www-spds-si"            = { name = "www.spds.si.trislab.com", type = "A", content = local.hosting }
  }
}

resource "cloudflare_dns_record" "existing" {
  for_each = local.existing_records
  zone_id  = cloudflare_zone.this["trislab.com"].id
  name     = each.value.name
  type     = each.value.type
  priority = try(each.value.priority, null)
  ttl      = 3600
  proxied  = false

  # Cloudflare stores TXT content quoted, one string of at most 255 characters
  # each, so it is written that way to keep the plan clean.
  content = each.value.type == "TXT" ? join(" ", formatlist("\"%s\"", regexall(".{1,255}", each.value.content))) : each.value.content
}
