# Cloudflare Zero Trust in the team trislab, with Entra ID sign-in through
# app-cloudflare-access, and one Access application per sandbox hostname
# (07-catalog-and-ipam.md section 3.3, ADR 0027, Technical details).

# Started by hand on the Free plan, because Cloudflare starts Zero Trust on an
# account only in the dashboard (09-bootstrap.md section 10).
import {
  to = cloudflare_zero_trust_organization.this
  id = "accounts/${var.cloudflare_account_id}"
}

resource "cloudflare_zero_trust_organization" "this" {
  account_id  = var.cloudflare_account_id
  name        = "trislab"
  auth_domain = "trislab.cloudflareaccess.com"
}

# ---- Entra ID sign-in --------------------------------------------------------
# spn-global-apply creates and owns the app registration with
# Application.ReadWrite.OwnedBy (ADR 0034). A Privileged Role Administrator
# consents to its delegated permissions by hand, once (09-bootstrap.md
# section 13).

data "azuread_client_config" "current" {}

data "azuread_service_principal" "global_apply" {
  display_name = "spn-global-apply"
}

locals {
  # Delegated Microsoft Graph permissions, by the IDs Microsoft publishes for
  # them. GroupMember.Read.All lets Access read a user's groups.
  access_scopes = {
    "openid"               = "37f7f235-527c-4136-accd-4a02d197296e"
    "email"                = "64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0"
    "profile"              = "14dad69e-099b-42c9-810b-d002981feec1"
    "offline_access"       = "7427e0e9-2fba-42fe-b0c0-848c9e6a8182"
    "User.Read"            = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"
    "GroupMember.Read.All" = "bc024368-1153-4739-b217-4326f2e966d0"
  }
}

resource "azuread_application" "access" {
  display_name     = "app-cloudflare-access"
  sign_in_audience = "AzureADMyOrg"
  owners           = [data.azuread_service_principal.global_apply.object_id]

  web {
    redirect_uris = ["https://trislab.cloudflareaccess.com/cdn-cgi/access/callback"]
  }

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

    dynamic "resource_access" {
      for_each = local.access_scopes
      content {
        id   = resource_access.value
        type = "Scope"
      }
    }
  }
}

resource "azuread_service_principal" "access" {
  client_id = azuread_application.access.client_id
  owners    = [data.azuread_service_principal.global_apply.object_id]
}

# Valid 24 months from its month, rotated every 12 (14-operating-model.md
# section 4): a PR that changes the month creates a new password, and the same
# apply gives it to Cloudflare.
locals {
  access_password_month = "2026-11"
}

resource "azuread_application_password" "access" {
  application_id = azuread_application.access.id
  display_name   = "cloudflare-access"
  end_date       = "${tonumber(split("-", local.access_password_month)[0]) + 2}-${split("-", local.access_password_month)[1]}-01T00:00:00Z"

  rotate_when_changed = {
    month = local.access_password_month
  }
}

resource "cloudflare_zero_trust_access_identity_provider" "entra" {
  account_id = var.cloudflare_account_id
  name       = "Entra ID"
  type       = "azureAD"

  config = {
    client_id      = azuread_application.access.client_id
    client_secret  = azuread_application_password.access.value
    directory_id   = data.azuread_client_config.current.tenant_id
    support_groups = true
  }
}

# ---- Access to sandbox hostnames ---------------------------------------------
# One reusable policy per owner with sandbox hostnames, admitting its Entra
# groups by object ID, and one self-hosted application per sandbox hostname,
# derived ones included. Production hostnames are public.

locals {
  sandbox_hostnames = { for fqdn, h in local.hostnames : fqdn => h if h.sandbox }

  access_groups = {
    for owner in distinct([for h in local.sandbox_hostnames : h.owner]) :
    owner => ["grp-devops", owner == "trislab" ? "grp-sandbox-trislab" : "grp-cust-${owner}-admins"]
  }
}

data "azuread_group" "access" {
  for_each         = toset(flatten(values(local.access_groups)))
  display_name     = each.key
  security_enabled = true
}

resource "cloudflare_zero_trust_access_policy" "sandbox" {
  for_each   = local.access_groups
  account_id = var.cloudflare_account_id
  name       = "sandbox-${each.key}"
  decision   = "allow"

  include = [
    for g in each.value : {
      azure_ad = {
        id                   = data.azuread_group.access[g].object_id
        identity_provider_id = cloudflare_zero_trust_access_identity_provider.entra.id
      }
    }
  ]
}

resource "cloudflare_zero_trust_access_application" "sandbox" {
  for_each                  = local.sandbox_hostnames
  account_id                = var.cloudflare_account_id
  name                      = each.key
  domain                    = each.key
  type                      = "self_hosted"
  allowed_idps              = [cloudflare_zero_trust_access_identity_provider.entra.id]
  auto_redirect_to_identity = true

  policies = [{
    id         = cloudflare_zero_trust_access_policy.sandbox[each.value.owner].id
    precedence = 1
  }]
}
