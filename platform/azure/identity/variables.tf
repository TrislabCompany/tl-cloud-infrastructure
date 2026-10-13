variable "github_owner_id" {
  description = "The organization's numeric ID, for the immutable OIDC subject (08-pipeline.md section 2, ADR 0045)."
  type        = string

  validation {
    condition     = can(regex("^[1-9][0-9]*$", var.github_owner_id))
    error_message = "github_owner_id must be a number. Do the workflows pass github.repository_owner_id?"
  }
}

variable "github_repository_id" {
  description = "The repository's numeric ID, for the immutable OIDC subject (08-pipeline.md section 2, ADR 0045)."
  type        = string

  validation {
    condition     = can(regex("^[1-9][0-9]*$", var.github_repository_id))
    error_message = "github_repository_id must be a number. Do the workflows pass github.repository_id?"
  }
}

variable "pim" {
  description = "Whether the Trislab groups get PIM-eligible instead of direct role assignments. False until Entra ID P2 is bought (ADR 0053)."
  type        = bool
  default     = false

  validation {
    condition     = !var.pim
    error_message = "The PIM-eligible assignments are written when Entra ID P2 is bought (ADR 0053)."
  }
}
