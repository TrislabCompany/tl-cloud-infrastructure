variable "cloudflare_account_id" {
  description = "The ID of Trislab's Cloudflare account, from the repository variable CLOUDFLARE_ACCOUNT_ID (08-pipeline.md section 2)."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{32}$", var.cloudflare_account_id))
    error_message = "cloudflare_account_id must be 32 hexadecimal characters. Is the repository variable CLOUDFLARE_ACCOUNT_ID set?"
  }
}

variable "alert_email_platform" {
  description = "The platform team's role mailbox, from the repository variable ALERT_EMAIL_PLATFORM, which every root gets (08-pipeline.md section 2). Cloudflare's notifications go to it (notifications.tf)."
  type        = string

  validation {
    condition     = can(regex("^[^@ ]+@[^@ ]+$", var.alert_email_platform))
    error_message = "alert_email_platform must be an e-mail address. Is the repository variable ALERT_EMAIL_PLATFORM set?"
  }
}
