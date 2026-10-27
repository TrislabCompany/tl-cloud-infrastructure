terraform {
  required_version = ">= 1.12.6"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.28"
    }
  }
}

# The workflows sign in to Cloudflare through CLOUDFLARE_API_TOKEN: the
# read-only token on plan, the edit token of the Environment global on apply
# (16-secrets.md section 7).
provider "cloudflare" {}
