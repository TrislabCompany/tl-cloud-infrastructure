variable "platform_suffix" {
  description = "The platform's 4-digit suffix, from the repository variable PLATFORM_SUFFIX (08-pipeline.md section 2)."
  type        = string

  validation {
    condition     = can(regex("^[1-9][0-9]{3}$", var.platform_suffix))
    error_message = "platform_suffix must be 4 digits. Is the repository variable PLATFORM_SUFFIX set?"
  }
}

variable "alert_email_platform" {
  description = "The platform team's shared mailbox, from the repository variable ALERT_EMAIL_PLATFORM (08-pipeline.md section 2)."
  type        = string

  validation {
    condition     = can(regex("^[^@ ]+@[^@ ]+[.][^@ ]+$", var.alert_email_platform))
    error_message = "alert_email_platform must be an e-mail address. Is the repository variable ALERT_EMAIL_PLATFORM set?"
  }
}
