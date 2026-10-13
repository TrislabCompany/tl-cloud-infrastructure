variable "platform_suffix" {
  description = "The platform's 4-digit suffix, from the repository variable PLATFORM_SUFFIX (08-pipeline.md section 2)."
  type        = string

  validation {
    condition     = can(regex("^[1-9][0-9]{3}$", var.platform_suffix))
    error_message = "platform_suffix must be 4 digits. Is the repository variable PLATFORM_SUFFIX set?"
  }
}
