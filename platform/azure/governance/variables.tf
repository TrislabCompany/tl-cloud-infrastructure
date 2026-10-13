variable "alert_email_finops" {
  description = "The FinOps owner's shared mailbox, from the repository variable ALERT_EMAIL_FINOPS (08-pipeline.md section 2)."
  type        = string

  validation {
    condition     = can(regex("^[^@ ]+@[^@ ]+[.][^@ ]+$", var.alert_email_finops))
    error_message = "alert_email_finops must be an e-mail address. Is the repository variable ALERT_EMAIL_FINOPS set?"
  }
}
