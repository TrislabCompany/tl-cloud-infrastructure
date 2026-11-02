# The version of the GHCR pull token, written into lz-<lz> as
# GHCR_PULL_TOKEN_VERSION. Stamps use it as value_wo_version of their
# <stamp>-ghcr-pull secret, so a raised version rewrites the token in every
# stamp. The token itself never goes through OpenTofu: shared-apply.yml copies
# the landingzones secret GHCR_PULL_TOKEN into lz-<lz> after each apply (ADR 0026).
#
# A rotation stores the new token in the Environment landingzones first, then
# raises this version in a PR, which plans every landing zone and every stamp
# (16-secrets.md section 13.5).
locals {
  ghcr_pull_token_version = 1

  # The module creates lz-<lz> only for an active landing zone that isn't an
  # experiment (05-landing-zones.md section 7).
  lz          = yamldecode(file("${path.module}/../${var.landing_zone}.yaml"))
  environment = local.lz.archetype != "experiment" && local.lz.state == "active"
}

resource "github_actions_environment_variable" "ghcr_pull_token_version" {
  count         = local.environment ? 1 : 0
  repository    = "tl-cloud-infrastructure"
  environment   = "lz-${var.landing_zone}"
  variable_name = "GHCR_PULL_TOKEN_VERSION"
  value         = tostring(local.ghcr_pull_token_version)

  depends_on = [module.landing_zone]
}
