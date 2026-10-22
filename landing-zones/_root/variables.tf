variable "landing_zone" {
  description = "The landing zone to plan, the name of its landing-zones/<lz>.yaml, which is also the state key (08-pipeline.md section 2)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", var.landing_zone))
    error_message = "landing_zone must be a landing zone name. Is TF_VAR_landing_zone set?"
  }
}

variable "platform_suffix" {
  description = "The 4-digit suffix of the platform's global names, from the repository variable PLATFORM_SUFFIX (03 section 6)."
  type        = string

  validation {
    condition     = var.platform_suffix != ""
    error_message = "platform_suffix is empty. Is the repository variable PLATFORM_SUFFIX set?"
  }
}

variable "github_owner_id" {
  description = "The organization's numeric ID, for the immutable OIDC subject (ADR 0045)."
  type        = string

  validation {
    condition     = var.github_owner_id != ""
    error_message = "github_owner_id is empty."
  }
}

variable "github_repository_id" {
  description = "The numeric ID of tl-cloud-infrastructure, for the immutable OIDC subject (ADR 0045)."
  type        = string

  validation {
    condition     = var.github_repository_id != ""
    error_message = "github_repository_id is empty."
  }
}

variable "az_billing_account" {
  description = "The billing account name, from the repository variable AZ_BILLING_ACCOUNT (ADR 0011)."
  type        = string

  validation {
    condition     = var.az_billing_account != ""
    error_message = "az_billing_account is empty. Is the repository variable AZ_BILLING_ACCOUNT set?"
  }
}

variable "az_billing_profile" {
  description = "The billing profile name, from the repository variable AZ_BILLING_PROFILE (ADR 0011)."
  type        = string

  validation {
    condition     = var.az_billing_profile != ""
    error_message = "az_billing_profile is empty. Is the repository variable AZ_BILLING_PROFILE set?"
  }
}
