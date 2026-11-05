# The action group a prod landing zone's stamps send their alert rules to
# (06 section 6.8), written into lz-<lz> as ALERT_ACTION_GROUP_IDS, a JSON list
# of resource IDs. It e-mails the same mailbox as ag-platform.
#
# It lives in the landing zone's own subscription, not in sub-platform: an
# alert rule that names an action group in another subscription needs its
# caller to read the action group's resource group (governance/finops.tf, PR
# #54), and rg-platform-management also holds log-platform. Here the stamp's
# deploy identity already has Contributor. A sandbox stamp has no alert rules,
# so a sandbox landing zone has no action group.
locals {
  alerts = local.environment && strcontains(var.landing_zone, "-prod-")
}

resource "azapi_resource" "action_group" {
  count     = local.alerts ? 1 : 0
  type      = "Microsoft.Insights/actionGroups@2023-01-01"
  parent_id = "/subscriptions/${module.landing_zone.subscription_id}/resourceGroups/rg-${var.landing_zone}-security"
  name      = "ag-${var.landing_zone}"
  location  = "global"
  tags = {
    Product         = "platform"
    Customer        = "trislab"
    EnvironmentType = "prod"
    EnvironmentName = "prod"
  }
  body = {
    properties = {
      enabled        = true
      groupShortName = substr(replace(var.landing_zone, "-", ""), 0, 12)
      emailReceivers = [{
        name                 = "platform"
        emailAddress         = var.alert_email_platform
        useCommonAlertSchema = true
      }]
    }
  }

  # Created after the module's resource group and lock, and deleted before
  # them.
  depends_on = [module.landing_zone]
}

resource "github_actions_environment_variable" "alert_action_group_ids" {
  count         = local.alerts ? 1 : 0
  repository    = "tl-cloud-infrastructure"
  environment   = "lz-${var.landing_zone}"
  variable_name = "ALERT_ACTION_GROUP_IDS"
  value         = jsonencode([azapi_resource.action_group[0].id])

  depends_on = [module.landing_zone]
}
