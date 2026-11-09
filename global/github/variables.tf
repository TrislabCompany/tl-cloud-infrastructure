variable "cloudflare_account_id" {
  description = "The ID of Trislab's Cloudflare account, from the repository variable CLOUDFLARE_ACCOUNT_ID (08-pipeline.md section 2)."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{32}$", var.cloudflare_account_id))
    error_message = "cloudflare_account_id must be 32 hexadecimal characters. Is the repository variable CLOUDFLARE_ACCOUNT_ID set?"
  }
}
