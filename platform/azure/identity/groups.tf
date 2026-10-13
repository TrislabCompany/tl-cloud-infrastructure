# The Trislab groups of 02-architecture.md section 6. The tenant owner adds
# the members by hand; no member is written here. spn-platform-apply creates
# them with Group.Create and owns them, which lets it manage them. It reads
# them back, owners included, with Group.Read.All (ADR 0034).
# grp-cust-<code>-admins come with the first customer in catalog/owners.yaml.

locals {
  groups = {
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
  }

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
