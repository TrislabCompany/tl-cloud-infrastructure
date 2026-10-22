# One state per landing zone: the pipeline plans this root once per
# landing-zones/<lz>.yaml, with the name as TF_VAR_landing_zone and as the
# state key (08-pipeline.md section 2).
locals {
  owners  = yamldecode(file("${path.module}/../../catalog/owners.yaml"))
  regions = yamldecode(file("${path.module}/../../catalog/regions.yaml"))
  ipam    = yamldecode(file("${path.module}/../../catalog/ipam.yaml"))
}

module "landing_zone" {
  source = "git::https://github.com/TrislabCompany/tl-platform.git//landing-zone?ref=v0.1.0"

  providers = {
    azurerm    = azurerm
    azurerm.lz = azurerm.lz
  }

  lz = yamldecode(file("${path.module}/../${var.landing_zone}.yaml"))
  catalog = {
    owners        = local.owners.owners
    regions       = local.regions.regions
    landing_zones = try(local.ipam.landing_zones, null)
  }

  platform_suffix      = var.platform_suffix
  github_owner_id      = var.github_owner_id
  github_repository_id = var.github_repository_id
  az_billing_account   = var.az_billing_account
  az_billing_profile   = var.az_billing_profile

  # is-platform was made by hand, so its ID isn't its name (ADR 0011).
  az_platform_invoice_section = "FLNE-ZNPI-PJA-PGB"

  # spn-global-plan and spn-global-apply. The landingzones identities can't
  # read service principals, so the IDs are written here (ADR 0027).
  edge_reader_ids = [
    "0d1a0012-5c20-47bf-84b1-dbe55d285a65",
    "88fa6881-fefa-4264-9ce0-20021e3b90fe",
  ]
}
