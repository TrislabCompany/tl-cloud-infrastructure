# Cloudflare's free notifications, to the platform team's role mailbox
# (ADR 0060). Cloudflare stops attacks and renews certificates by itself; these
# tell a person when it happened, before a client notices.
#
# No Pages deployment alert: Cloudflare refuses a pages_event_alert without a
# project filter whose format it doesn't document, and each site deploys from
# its own GitHub workflow, whose failed run already notifies.

locals {
  notifications = {
    # An HTTP DDoS attack Cloudflare mitigated on any zone of the account.
    ddos-http = { alert_type = "dos_attack_l7", description = "An HTTP DDoS attack was mitigated on a Trislab zone" }
    # Universal SSL: a certificate was issued, renewed or failed validation.
    universal-ssl = { alert_type = "universal_ssl_event_type", description = "A universal edge certificate changed or failed" }
  }
}

resource "cloudflare_notification_policy" "this" {
  for_each    = local.notifications
  account_id  = var.cloudflare_account_id
  name        = "edge-${each.key}"
  description = each.value.description
  alert_type  = each.value.alert_type
  enabled     = true

  mechanisms = {
    email = [{ id = var.alert_email_platform }]
  }
}
