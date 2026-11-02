# One Cloudflare Origin CA certificate per zone, for <zone> and *.<zone>, valid
# 15 years. The key and certificate are written into the Environment lz-<lz> of
# every landing zone with stamp hostnames in the zone, as the secret
# ORIGIN_CERT_<ZONE> and the variable ORIGIN_CERT_<ZONE>_VERSION; the stamp
# writes them into its Key Vault (ADR 0026, ADR 0027, Technical details,
# Origin certificate). The key is in the encrypted state and saved plans of
# global/edge, and masked in every plan text (ADR 0046).
#
# A replaced key means a new certificate: the PR that replaces tls_private_key
# raises the zone's version, so every stamp in the zone writes the new
# certificate on its next apply.

locals {
  # Zone => version, from 1.
  origin_cert_versions = {}

  origin_cert_targets = {
    for pair in distinct([for h in local.hostnames : { zone = h.zone, lz = h.lz } if h.zone != null]) :
    "${pair.lz}/${pair.zone}" => merge(pair, { name = "ORIGIN_CERT_${upper(replace(pair.zone, "/[.-]/", "_"))}" })
  }
}

resource "tls_private_key" "origin" {
  for_each  = local.domains
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "origin" {
  for_each        = local.domains
  private_key_pem = tls_private_key.origin[each.key].private_key_pem
  dns_names       = [each.key, "*.${each.key}"]

  subject {
    common_name = each.key
  }
}

# The hostnames are in the order Cloudflare returns them: a change in the list
# replaces the certificate.
resource "cloudflare_origin_ca_certificate" "this" {
  for_each           = local.domains
  csr                = tls_cert_request.origin[each.key].cert_request_pem
  hostnames          = ["*.${each.key}", each.key]
  request_type       = "origin-rsa"
  requested_validity = 5475
}

resource "github_actions_environment_secret" "origin_cert" {
  for_each        = local.origin_cert_targets
  repository      = "tl-cloud-infrastructure"
  environment     = "lz-${each.value.lz}"
  secret_name     = each.value.name
  plaintext_value = "${chomp(cloudflare_origin_ca_certificate.this[each.value.zone].certificate)}\n${tls_private_key.origin[each.value.zone].private_key_pem}"
}

resource "github_actions_environment_variable" "origin_cert_version" {
  for_each      = local.origin_cert_targets
  repository    = "tl-cloud-infrastructure"
  environment   = "lz-${each.value.lz}"
  variable_name = "${each.value.name}_VERSION"
  value         = tostring(lookup(local.origin_cert_versions, each.value.zone, 1))
}
