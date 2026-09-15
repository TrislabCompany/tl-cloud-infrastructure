# shared-infrastructure/azure/tags.tf
# Mandatory FinOps tags (docs/spec/NAMING-CONVENTIONS.md#mandatory-tagslabels), as inputs
# so every resource in this workload gets them via local.mandatory_tags instead of each
# resource block hardcoding its own copy.

variable "customer" {
  type        = string
  description = "Mandatory Customer tag value. \"trislab\" for shared-infra resources, which have no external customer."
  default     = "trislab"
}

variable "product" {
  type        = string
  description = "Mandatory Product tag value for this workload."
  default     = "shared-infra"
}

variable "environment" {
  type        = string
  description = "Mandatory Environment tag value — the environment type."
  default     = "production"

  validation {
    condition     = contains(["sandbox", "production"], var.environment)
    error_message = "environment must be \"sandbox\" or \"production\"."
  }
}

variable "environment_name" {
  type        = string
  description = "Mandatory EnvironmentName tag value — the specific environment instance (e.g. dev, test, staging, demo, prod)."
  default     = "prod"
}

locals {
  mandatory_tags = {
    Customer        = var.customer
    Product         = var.product
    Environment     = var.environment
    EnvironmentName = var.environment_name
  }
}
