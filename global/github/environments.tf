# One Environment per stamp that deploys from a repository, named after the
# stamp's app_environment, with the deploy variables (ADR 0038,
# 11-onboarding.md section 4.3). One Azure Resource Graph query reads the
# app-deploy identities through Edge stamp reader; a stamp whose identity
# doesn't exist yet gets no Environment.

locals {
  identity_names = toset([for d in local.deployments : "id-${local.stamps[d.stamp].code}-appdeploy"])
}

data "azapi_resource_action" "identities" {
  count       = length(local.identity_names) > 0 ? 1 : 0
  type        = "Microsoft.ResourceGraph@2022-10-01"
  resource_id = "/providers/Microsoft.ResourceGraph"
  action      = "resources"
  method      = "POST"
  body = {
    query = "resources | where type =~ 'microsoft.managedidentity/userassignedidentities' and name in~ (${join(", ", [for n in local.identity_names : "'${n}'"])}) | project name, subscriptionId, clientId = tostring(properties.clientId), tenantId = tostring(properties.tenantId)"
  }
  response_export_values = ["data"]
}

locals {
  identities = {
    for i in try(data.azapi_resource_action.identities[0].output.data, []) : i.name => i
  }

  environments = {
    for key, d in local.deployments : key => merge(d, local.stamps[d.stamp], {
      identity = local.identities["id-${local.stamps[d.stamp].code}-appdeploy"]
    })
    if contains(keys(local.identities), "id-${local.stamps[d.stamp].code}-appdeploy")
  }

  # PLATFORM_TIER from the stamp's environment (11-onboarding.md section 8.1).
  environment_variables = merge([
    for key, e in local.environments : {
      for name, value in {
        AZURE_CLIENT_ID       = e.identity.clientId
        AZURE_TENANT_ID       = e.identity.tenantId
        AZURE_SUBSCRIPTION_ID = e.identity.subscriptionId
        RESOURCE_GROUP        = "rg-${e.code}"
        CONTAINER_APPS        = jsonencode({ for a in e.apps : a.name => "ca-${e.code}-${a.name}" })
        PLATFORM_TIER         = e.environment == "dev" ? "dev" : e.environment == "prod" ? "prod" : can(regex("^pr[0-9]+$", e.environment)) ? "preview" : "release"
      } : "${key}/${name}" => { environment = key, name = name, value = value }
    }
  ]...)
}

# A stamp in a prod landing zone trusts any job in its Environment, so that
# Environment gets reviewers (ADR 0038).
resource "github_repository_environment" "this" {
  for_each            = local.environments
  repository          = github_repository.this[each.value.repo].name
  environment         = each.value.app_environment
  prevent_self_review = each.value.prod

  dynamic "reviewers" {
    for_each = each.value.prod ? [1] : []
    content {
      teams = [tonumber(data.github_team.devops.id), tonumber(github_team.product[local.repos[each.value.repo].team].id)]
    }
  }
}

resource "github_actions_environment_variable" "this" {
  for_each      = local.environment_variables
  repository    = github_repository_environment.this[each.value.environment].repository
  environment   = github_repository_environment.this[each.value.environment].environment
  variable_name = each.value.name
  value         = each.value.value
}
