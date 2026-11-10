# The Trislab groups of 02-architecture.md section 6. The tenant owner adds
# the members by hand; no member is written here. spn-platform-apply creates
# them with Group.Create and owns them, which lets it manage them. It reads
# them back, owners included, with Group.Read.All (ADR 0034).
# grp-cust-<code>-admins are created for every active client tenant (a tenant
# with a code) in catalog/products.yaml; Cloudflare Access admits them to the
# tenant's protected hostnames (global/edge/zero-trust.tf). A retired tenant's
# group is deleted with it.
# A prod landing zone's grp-data-<lz>-readers and -admins come in their own PR
# before the landing zone's, and stay until it is cancelled: policy/catalog.rego
# denies a plan that deletes one earlier.

locals {
  # The client tenants of catalog/products.yaml (trislab has no code).
  client_tenants = [
    for t in yamldecode(file("${path.module}/../../../catalog/products.yaml")).tenants : t
    if try(t.code, null) != null && t.state == "active"
  ]

  customer_groups = {
    for t in local.client_tenants : "cust-${t.code}-admins" => {
      name        = "grp-cust-${t.code}-admins"
      description = "The administrators of the client ${t.slug}, admitted to its protected hostnames by Cloudflare Access (07-catalog-and-ipam.md section 3.3)."
    }
  }

  groups = merge(local.customer_groups, {
    devops = {
      name        = "grp-devops"
      description = "The members of the GitHub team devops (ADR 0031)."
    }
    platform-admins = {
      name        = "grp-platform-admins"
      description = "The governance and security owners (14-operating-model.md section 2)."
    }
    regulated-admins = {
      name        = "grp-regulated-admins"
      description = "Trislab engineers who may work in regulated landing zones (ADR 0052)."
    }
    data-sandbox-readers = {
      name        = "grp-data-sandbox-readers"
      description = "Read the data of the sandbox landing zones' stamps (ADR 0052)."
    }
    data-sandbox-admins = {
      name        = "grp-data-sandbox-admins"
      description = "Administer the data of the sandbox landing zones' stamps (ADR 0052)."
    }
    data-products-prod-neu-readers = {
      name        = "grp-data-products-prod-neu-readers"
      description = "Read the data of the stamps in products-prod-neu (ADR 0052)."
    }
    data-products-prod-neu-admins = {
      name        = "grp-data-products-prod-neu-admins"
      description = "Administer the data of the stamps in products-prod-neu (ADR 0052)."
    }
    sandbox-trislab = {
      name        = "grp-sandbox-trislab"
      description = "Admitted to Trislab's sandbox hostnames by Cloudflare Access (07-catalog-and-ipam.md section 3.3)."
    }
  })

  # Reader on mg-root (02-architecture.md section 6), direct while pim is false
  # (ADR 0053).
  group_readers = toset(["devops", "platform-admins"])
}

resource "azuread_group" "this" {
  for_each         = local.groups
  display_name     = each.value.name
  description      = each.value.description
  security_enabled = true
  owners           = [local.spn_platform_apply]
}

resource "azurerm_role_assignment" "group_reader" {
  for_each             = var.pim ? toset([]) : local.group_readers
  scope                = "${local.mg}/mg-root"
  role_definition_name = "Reader"
  principal_id         = azuread_group.this[each.key].object_id
  principal_type       = "Group"
}
