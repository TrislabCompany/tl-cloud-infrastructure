# Cloudflare's free notifications, to the platform team's role mailbox
# (ADR 0060). Cloudflare stops attacks and renews certificates by itself; these
# tell a person when it happened, before a client notices.

locals {
  notifications = {
    # An HTTP DDoS attack Cloudflare mitigated on any zone of the account.
    ddos-http = { alert_type = "dos_attack_l7", description = "An HTTP DDoS attack was mitigated on a Trislab zone", filters = null }
    # Universal SSL: a certificate was issued, renewed or failed validation.
    universal-ssl = { alert_type = "universal_ssl_event_type", description = "A universal edge certificate changed or failed", filters = null }
    # A deployment of a site on Cloudflare Pages failed.
    pages-deploy-failed = { alert_type = "pages_event_alert", description = "A Pages deployment failed", filters = { event = ["EVENT_DEPLOYMENT_FAILED"] } }
  }
}

resource "cloudflare_notification_policy" "this" {
  for_each    = local.notifications
  account_id  = var.cloudflare_account_id
  name        = "edge-${each.key}"
  description = each.value.description
  alert_type  = each.value.alert_type
  enabled     = true
  filters     = each.value.filters

  mechanisms = {
    email = [{ id = var.alert_email_platform }]
  }
}
