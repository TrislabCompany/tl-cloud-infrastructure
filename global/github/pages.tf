# The GitHub side of the sites on Cloudflare Pages (pages in
# catalog/repos.yaml; global/edge/pages.tf creates the projects): one
# Environment per environment of a site, with the variables and the secret its
# deploy workflow reads, and one Cloudflare account token per site that may
# only deploy to Pages. Cloudflare can't limit a token to one project, so
# production gets reviewers and every Environment deploys only from main.

locals {
  pages = {
    for p in try(yamldecode(file("${path.module}/../../catalog/repos.yaml")).pages, []) : p.repo => p
    if contains(keys(local.repos), p.repo)
  }

  pages_environments = merge([
    for repo, p in local.pages : {
      for e in p.environments : "${repo}/${e.name}" => {
        repo        = repo
        environment = e.name
        production  = e.name == "production"
        public      = try(e.access, "protected") == "public"
        hostname    = e.hostname
      }
    }
  ]...)

  # ROBOTS_INDEX lets search engines index a public production only.
  pages_variables = merge([
    for key, e in local.pages_environments : {
      for name, value in merge(
        {
          CLOUDFLARE_ACCOUNT_ID = var.cloudflare_account_id
          PAGES_PROJECT         = e.repo
          SITE_URL              = "https://${e.hostname}"
        },
        e.production && e.public ? { ROBOTS_INDEX = "true" } : {},
      ) : "${key}/${name}" => { environment = key, name = name, value = value }
    }
  ]...)
}

resource "github_repository_environment" "pages" {
  for_each            = local.pages_environments
  repository          = github_repository.this[each.value.repo].name
  environment         = each.value.environment
  prevent_self_review = each.value.production

  dynamic "reviewers" {
    for_each = each.value.production ? [1] : []
    content {
      teams = [tonumber(data.github_team.devops.id), tonumber(github_team.product[local.repos[each.value.repo].product].id)]
    }
  }

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "pages" {
  for_each       = local.pages_environments
  repository     = github_repository_environment.pages[each.key].repository
  environment    = github_repository_environment.pages[each.key].environment
  branch_pattern = "main"
}

resource "github_actions_environment_variable" "pages" {
  for_each      = local.pages_variables
  repository    = github_repository_environment.pages[each.value.environment].repository
  environment   = github_repository_environment.pages[each.value.environment].environment
  variable_name = each.value.name
  value         = each.value.value
}

# ---- The deploy token --------------------------------------------------------
# Created and revoked with the site's entry. Its value is in the encrypted state
# of global/github (ADR 0046), and replaced by tainting the token in a PR.

data "cloudflare_account_api_token_permission_groups_list" "pages_write" {
  account_id = var.cloudflare_account_id
  name       = "Pages Write"
}

resource "cloudflare_account_token" "pages" {
  for_each   = local.pages
  account_id = var.cloudflare_account_id
  name       = "pages-deploy-${each.key}"

  policies = [{
    effect            = "allow"
    permission_groups = [{ id = one([for g in data.cloudflare_account_api_token_permission_groups_list.pages_write.result : g.id if g.name == "Pages Write"]) }]
    resources         = jsonencode({ "com.cloudflare.api.account.${var.cloudflare_account_id}" = "*" })
  }]
}

resource "github_actions_environment_secret" "pages_token" {
  for_each        = local.pages_environments
  repository      = github_repository_environment.pages[each.key].repository
  environment     = github_repository_environment.pages[each.key].environment
  secret_name     = "CLOUDFLARE_API_TOKEN"
  plaintext_value = cloudflare_account_token.pages[each.value.repo].value
}

# ---- Release tags --------------------------------------------------------------
# A release tag vX.Y.Z is made once, by the site's workflow Release new
# version, and never moved or deleted: staging and production deploy by it.

resource "github_repository_ruleset" "pages_tags" {
  for_each    = local.pages
  name        = "release tags"
  repository  = github_repository.this[each.key].name
  target      = "tag"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["refs/tags/v*"]
      exclude = []
    }
  }

  rules {
    deletion         = true
    update           = true
    non_fast_forward = true
  }
}
