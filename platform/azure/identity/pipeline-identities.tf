# The pipeline identities of 02-architecture.md section 6. The seed created
# spn-platform-plan and spn-platform-apply by hand (09-bootstrap.md section 6);
# they are adopted here with import blocks (09-bootstrap.md section 12).
# spn-platform-apply owns every app registration and service principal here,
# which is all Application.ReadWrite.OwnedBy lets it change (ADR 0034). Their
# rights on the state containers come from platform/azure/state (ADR 0032).

locals {
  mg = "/providers/Microsoft.Management/managementGroups"

  spn_platform_apply = "be8c78c8-eba1-4c36-8be1-a4b0a2ff2fd1"

  # The immutable OIDC subject, pinned to main's reusable workflows
  # (08-pipeline.md section 2, ADR 0045).
  subject_prefix = "repo:TrislabCompany@${var.github_owner_id}/tl-cloud-infrastructure@${var.github_repository_id}"
  workflows      = "job_workflow_ref:TrislabCompany/tl-cloud-infrastructure/.github/workflows"

  # Microsoft Graph application permissions, by the IDs Microsoft publishes for
  # them. Written here, so a plan identity needs no read of the Graph service
  # principal. Each identity requests its permissions in code, and a Privileged
  # Role Administrator consents by hand (ADR 0034).
  graph = {
    "Application.Read.All"          = "9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30"
    "Application.ReadWrite.OwnedBy" = "18a4783c-866b-4cc7-a460-3d5e5662c884"
    "Group.Create"                  = "bf7b1a76-6e77-406b-b258-bf5c7720e98f"
    "Group.Read.All"                = "5b567255-7703-4780-807c-7be8301ae99b"
  }

  # Plan identities trust pull_request and main, apply identities their
  # Environment (08-pipeline.md section 2).
  plan_trust = {
    pull-request = "pull_request"
    main         = "ref:refs/heads/main"
  }

  identities = {
    platform-plan = {
      workflow = "shared-plan.yml"
      trust    = local.plan_trust
      graph    = ["Application.Read.All", "Group.Read.All"]
    }
    platform-apply = {
      workflow = "shared-apply.yml"
      trust    = { platform = "environment:platform" }
      graph    = ["Application.ReadWrite.OwnedBy", "Group.Create"]
    }
    global-plan = {
      workflow = "shared-plan.yml"
      trust    = local.plan_trust
      graph    = []
    }
    global-apply = {
      workflow = "shared-apply.yml"
      trust    = { global = "environment:global" }
      graph    = []
    }
    landingzones-plan = {
      workflow = "shared-plan.yml"
      trust    = local.plan_trust
      graph    = ["Group.Read.All"]
    }
    landingzones-apply = {
      workflow = "shared-apply.yml"
      trust    = { landingzones = "environment:landingzones" }
      graph    = ["Application.ReadWrite.OwnedBy", "Group.Read.All"]
    }
  }

  credentials = merge([
    for id, i in local.identities : {
      for name, context in i.trust : "${id}/${name}" => {
        identity = id
        name     = name
        subject  = "${local.subject_prefix}:${context}:${local.workflows}/${i.workflow}@refs/heads/main"
      }
    }
  ]...)

  # The seed's object IDs (scripts A5.1 and A5.2 of phase 3). The keys of
  # credentials are the federated credential IDs.
  seed = {
    platform-plan = {
      application       = "2d82af99-7f71-4455-8396-c3394aa3a987"
      service_principal = "b8f0ba1b-29df-48e3-b736-96171e65f145"
      credentials = {
        pull-request = "48fb45f3-7471-476d-be3c-4a595fd4779e"
        main         = "35b055cb-61d4-4e2a-a639-1e58a1870799"
      }
    }
    platform-apply = {
      application       = "978c6d90-de78-44d1-a928-d36cbf1e0ece"
      service_principal = local.spn_platform_apply
      credentials = {
        platform = "5f25ddae-596e-48d5-8f82-0bdb0e57cb9e"
      }
    }
  }
}

import {
  for_each = local.seed
  to       = azuread_application.this[each.key]
  id       = "/applications/${each.value.application}"
}

resource "azuread_application" "this" {
  for_each     = local.identities
  display_name = "spn-${each.key}"
  owners       = [local.spn_platform_apply]

  dynamic "required_resource_access" {
    for_each = length(each.value.graph) > 0 ? [each.value.graph] : []
    content {
      resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

      dynamic "resource_access" {
        for_each = required_resource_access.value
        content {
          id   = local.graph[resource_access.value]
          type = "Role"
        }
      }
    }
  }
}

import {
  for_each = local.seed
  to       = azuread_service_principal.this[each.key]
  id       = "/servicePrincipals/${each.value.service_principal}"
}

resource "azuread_service_principal" "this" {
  for_each  = local.identities
  client_id = azuread_application.this[each.key].client_id
  owners    = [local.spn_platform_apply]
}

import {
  for_each = merge([
    for id, s in local.seed : {
      for name, credential in s.credentials : "${id}/${name}" => "${s.application}/federatedIdentityCredential/${credential}"
    }
  ]...)
  to = azuread_application_federated_identity_credential.this[each.key]
  id = each.value
}

resource "azuread_application_federated_identity_credential" "this" {
  for_each       = local.credentials
  application_id = azuread_application.this[each.value.identity].id
  display_name   = each.value.name
  issuer         = "https://token.actions.githubusercontent.com"
  audiences      = ["api://AzureADTokenExchange"]
  subject        = each.value.subject
}

# ---- Roles on the management groups -----------------------------------------
# The roles of spn-platform-plan and spn-platform-apply are in
# platform/azure/governance. spn-global-plan and spn-global-apply get
# "Edge stamp reader" on each landing zone subscription from the landing-zone
# module (05-landing-zones.md section 4).

locals {
  # The landingzones layer's scope (02-architecture.md section 6, ADR 0011).
  lz_scopes = toset(["mg-landingzones", "mg-experiments", "mg-decommissioned"])

  lz_roles = {
    for pair in setproduct(
      ["landingzones-plan/Reader", "landingzones-apply/Contributor", "landingzones-apply/Management Group Contributor"],
      local.lz_scopes,
      ) : "${pair[0]}/${pair[1]}" => {
      identity = split("/", pair[0])[0]
      role     = split("/", pair[0])[1]
      scope    = pair[1]
    }
  }

  # The fixed set of roles spn-landingzones-apply may assign
  # (02-architecture.md section 6, ADR 0024, ADR 0027).
  lz_assignable = [
    "acdd72a7-3385-48ef-bd42-f606fba81ae7", # Reader
    "b24988ac-6180-42a0-ab88-20f7382dd24c", # Contributor
    "21090545-7ca7-4776-b22c-e363652d74d2", # Key Vault Reader
    "b86a8fe4-44ce-4948-aee5-eccb2c155cd7", # Key Vault Secrets Officer
    "f58310d9-a9f6-439a-9e8d-f62e7b41a168", # Role Based Access Control Administrator
    data.azurerm_role_definition.edge_stamp_reader.role_definition_id,
  ]
  lz_assignable_list = join(", ", local.lz_assignable)
}

# Defined in platform/azure/governance.
data "azurerm_role_definition" "edge_stamp_reader" {
  name  = "Edge stamp reader"
  scope = "${local.mg}/mg-landingzones"
}

resource "azurerm_role_assignment" "lz" {
  for_each             = local.lz_roles
  scope                = "${local.mg}/${each.value.scope}"
  role_definition_name = each.value.role
  principal_id         = azuread_service_principal.this[each.value.identity].object_id
  principal_type       = "ServicePrincipal"
}

# User Access Administrator, limited to assigning and removing the fixed set
# of landing zone roles (ADR 0024).
resource "azurerm_role_assignment" "lz_access" {
  for_each             = local.lz_scopes
  scope                = "${local.mg}/${each.key}"
  role_definition_name = "User Access Administrator"
  principal_id         = azuread_service_principal.this["landingzones-apply"].object_id
  principal_type       = "ServicePrincipal"
  condition_version    = "2.0"
  condition            = "((!(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})) OR (@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.lz_assignable_list}})) AND ((!(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})) OR (@Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.lz_assignable_list}}))"
}
