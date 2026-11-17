# The GitHub side of the workers (the products with environments in
# catalog/products.yaml that are workers; global/edge/workers.tf creates the
# Workers and their hostnames), as pages.tf is for the sites: one Environment
# per environment of a worker, with the variables and the secret its deploy
# workflow reads, one Cloudflare account token per worker that may only deploy
# Workers, and the release tag ruleset. The forms worker (forms: true) also
# gets the Turnstile secret of every site environment with turnstile: true, in
# its Environment of the same name, so the sites' widgets and its secrets come
# from one place (ADR 0060, D-32).

locals {
  workers = {
    for repo, r in local.repos : repo => r
    if r.worker && length(r.environments) > 0
  }

  # The Worker's name is <environment>-<product>-<tenant>, as global/edge/workers.tf names it.
  worker_environments = merge([
    for repo, w in local.workers : {
      for e in w.environments : "${repo}/${e.name}" => {
        repo        = repo
        environment = e.name
        production  = e.name == "production"
        hostname    = e.hostname
        worker_name = "${e.name}-${w.product}-${w.tenant}"
        forms       = w.forms
      }
    }
  ]...)

  worker_variables = merge([
    for key, e in local.worker_environments : {
      for name, value in {
        CLOUDFLARE_ACCOUNT_ID = var.cloudflare_account_id
        WORKER_NAME           = e.worker_name
        WORKER_URL            = "https://${e.hostname}"
      } : "${key}/${name}" => { environment = key, name = name, value = value }
    }
  ]...)

  # The form endpoint of each environment, for the sites (pages.tf). The
  # catalog has at most one forms worker (policy/catalog.rego).
  forms_urls = { for key, e in local.worker_environments : e.environment => "https://${e.hostname}" if e.forms }

  # ---- Turnstile ----
  # The widgets are global/edge's (turnstile.tf), named <repo>-<environment>.
  # This root reads them, so no state is shared between the roots.
  turnstile_sites = { for key, e in local.pages_environments : key => e if e.turnstile }

  turnstile_widget_list = try(data.cloudflare_turnstile_widgets.all[0].result, [])

  # By <repo>/<environment> of the site; a widget global/edge has not created yet is left out.
  turnstile_widgets = {
    for key, e in local.turnstile_sites : key => one([for w in local.turnstile_widget_list : w if w.name == replace(key, "/", "-")])
    if length([for w in local.turnstile_widget_list : w if w.name == replace(key, "/", "-")]) == 1
  }

  # Every site environment's secret, into the forms worker's Environment of the same name.
  worker_turnstile_secrets = merge([
    for key, e in local.worker_environments : {
      for site_key, _ in local.turnstile_widgets : "${key}/${site_key}" => {
        worker_environment = key
        site_environment   = site_key
        secret_name        = "TURNSTILE_SECRET_${upper(replace(local.pages_environments[site_key].repo, "-", "_"))}"
      } if local.pages_environments[site_key].environment == e.environment
    } if e.forms
  ]...)
}

resource "github_repository_environment" "workers" {
  for_each            = local.worker_environments
  repository          = github_repository.this[each.value.repo].name
  environment         = each.value.environment
  prevent_self_review = each.value.production

  dynamic "reviewers" {
    for_each = each.value.production ? [1] : []
    content {
      teams = [tonumber(data.github_team.devops.id), tonumber(github_team.product[local.repos[each.value.repo].team].id)]
    }
  }

  # As for the sites (pages.tf): a team is a required reviewer only once it has access.
  depends_on = [github_team_repository.product, github_team_repository.devops]

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "workers" {
  for_each       = local.worker_environments
  repository     = github_repository_environment.workers[each.key].repository
  environment    = github_repository_environment.workers[each.key].environment
  branch_pattern = "main"
}

resource "github_actions_environment_variable" "workers" {
  for_each      = local.worker_variables
  repository    = github_repository_environment.workers[each.value.environment].repository
  environment   = github_repository_environment.workers[each.value.environment].environment
  variable_name = each.value.name
  value         = each.value.value
}

# ---- The deploy token --------------------------------------------------------
# As for the sites: created and revoked with the worker's entry, its value in the
# encrypted state (ADR 0046). Cloudflare can't limit a token to one Worker, so
# production gets reviewers and every Environment deploys only from main.

data "cloudflare_account_api_token_permission_groups_list" "workers_write" {
  account_id = var.cloudflare_account_id
  name       = "Workers Scripts Write"
}

resource "cloudflare_account_token" "workers" {
  for_each   = local.workers
  account_id = var.cloudflare_account_id
  name       = "workers-deploy-${each.key}"

  policies = [{
    effect            = "allow"
    permission_groups = [{ id = one([for g in data.cloudflare_account_api_token_permission_groups_list.workers_write.result : g.id if g.name == "Workers Scripts Write"]) }]
    resources         = jsonencode({ "com.cloudflare.api.account.${var.cloudflare_account_id}" = "*" })
  }]
}

resource "github_actions_environment_secret" "workers_token" {
  for_each        = local.worker_environments
  repository      = github_repository_environment.workers[each.key].repository
  environment     = github_repository_environment.workers[each.key].environment
  secret_name     = "CLOUDFLARE_API_TOKEN"
  plaintext_value = cloudflare_account_token.workers[each.value.repo].value
}

# ---- Turnstile secrets ---------------------------------------------------------

data "cloudflare_turnstile_widgets" "all" {
  count      = length(local.turnstile_sites) > 0 ? 1 : 0
  account_id = var.cloudflare_account_id
  max_items  = 1000
}

# Read only for a forms worker, so no secret is in this state without one.
data "cloudflare_turnstile_widget" "forms" {
  for_each   = length([for e in local.worker_environments : e if e.forms]) > 0 ? local.turnstile_widgets : {}
  account_id = var.cloudflare_account_id
  sitekey    = each.value.sitekey
}

resource "github_actions_environment_secret" "workers_turnstile" {
  for_each        = local.worker_turnstile_secrets
  repository      = github_repository_environment.workers[each.value.worker_environment].repository
  environment     = github_repository_environment.workers[each.value.worker_environment].environment
  secret_name     = each.value.secret_name
  plaintext_value = data.cloudflare_turnstile_widget.forms[each.value.site_environment].secret
}

# ---- Release tags --------------------------------------------------------------
# As for the sites: a release tag vX.Y.Z is made once, by the worker's workflow
# Release new version, and never moved or deleted.

resource "github_repository_ruleset" "workers_tags" {
  for_each    = local.workers
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
