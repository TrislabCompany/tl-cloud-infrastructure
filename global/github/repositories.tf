# The app repositories of catalog/repos.yaml, created from their templates
# (ADR 0038, 11-onboarding.md section 4.3). Each stamp whose apps[].repo names
# a repository deploys from it.

locals {
  org    = "TrislabCompany"
  owners = yamldecode(file("${path.module}/../../catalog/owners.yaml")).owners
  repos = {
    for r in yamldecode(file("${path.module}/../../catalog/repos.yaml")).repos : r.name => r
    if r.state == "active"
  }

  # stamp.yaml by stamp folder, <lz>/<folder>.
  stamp_files = {
    for f in fileset("${path.module}/../../stamps", "*/*/stamp.yaml") :
    trimsuffix(f, "/stamp.yaml") => yamldecode(file("${path.module}/../../stamps/${f}"))
  }

  stamps = {
    for folder, s in local.stamp_files : folder => {
      lz          = s.lz
      environment = s.environment
      prod        = strcontains(s.lz, "-prod-")

      # <owner-code>-<product-code>-<environment>[-<number>]
      # (06-stamp-templates.md section 3.2).
      code = join("-", compact([
        startswith(s.lz, "products-") ? "shr" : startswith(s.lz, "cust-") ? split("-", s.lz)[1] : "",
        one([for o in local.owners : o.code if o.slug == s.product]),
        s.environment,
        try(tostring(s.number), ""),
      ]))

      # The environment, or <customer>-<environment> in a customer landing
      # zone (06-stamp-templates.md section 3.1, 11-onboarding.md section 2.2).
      app_environment = try(s.app_environment, null) != null ? s.app_environment : startswith(s.lz, "cust-") ? "${one([for o in local.owners : o.slug if o.code == split("-", s.lz)[1]])}-${s.environment}" : s.environment

      # minreplicas is 2 with zone redundancy, 0 otherwise (06 section 6.5).
      min_replicas = try(s.zone_redundant, false) == true ? 2 : 0
      apps         = s.apps
    }
  }

  # One per repository and stamp that deploys from it, with the stamp's apps
  # from that repository.
  deployments = merge([
    for folder, s in local.stamps : {
      for repo in distinct([for a in s.apps : a.repo if contains(keys(local.repos), try(a.repo, ""))]) :
      "${repo}/${folder}" => {
        repo  = repo
        stamp = folder
        apps  = [for a in s.apps : a if try(a.repo, "") == repo]
      }
    }
  ]...)

  # The repositories each landing zone's stamps deploy from.
  lz_repos = {
    for lz in distinct([for d in local.deployments : local.stamps[d.stamp].lz]) :
    lz => distinct([for d in local.deployments : d.repo if local.stamps[d.stamp].lz == lz])
  }
}

resource "github_repository" "this" {
  for_each   = local.repos
  name       = each.key
  visibility = "public"

  template {
    owner      = local.org
    repository = each.value.template
  }

  # The template is read only when the repository is created (07 section 11).
  # tl-github-plan can't read the merge settings, so they would always show as
  # changing; the repository keeps GitHub's defaults (ADR 0038).
  lifecycle {
    ignore_changes = [
      template,
      allow_merge_commit,
      allow_rebase_merge,
      allow_squash_merge,
      merge_commit_title,
      merge_commit_message,
      squash_merge_commit_title,
      squash_merge_commit_message,
    ]
  }
}

# Written before the ruleset, which would refuse a direct commit. The product
# team owns the file afterwards and keeps the devops lines (ADR 0038,
# Technical details, CODEOWNERS).
resource "github_repository_file" "codeowners" {
  for_each            = local.repos
  repository          = github_repository.this[each.key].name
  branch              = "main"
  file                = ".github/CODEOWNERS"
  commit_message      = "CODEOWNERS for the team ${each.value.product} (ADR 0038)"
  overwrite_on_create = true
  content             = <<-EOT
    * @${local.org}/${each.value.product}
    /.github/ @${local.org}/${each.value.product} @${local.org}/devops
    /platform.yaml @${local.org}/${each.value.product} @${local.org}/devops
    /.trivyignore @${local.org}/${each.value.product} @${local.org}/devops
  EOT

  lifecycle {
    ignore_changes = [content, commit_message]
  }
}

resource "github_repository_ruleset" "main" {
  for_each    = local.repos
  name        = "main"
  repository  = github_repository.this[each.key].name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  rules {
    deletion         = true
    non_fast_forward = true

    pull_request {
      required_approving_review_count = 1
    }

    # The job ci of the repository's ci.yml, calling the job ci of app-ci.yml
    # (11-onboarding.md section 4.3).
    required_status_checks {
      required_check {
        context        = "ci / ci"
        integration_id = 15368 # GitHub Actions
      }
    }
  }

  depends_on = [github_repository_file.codeowners]
}

# Read access to the repository gives the GHCR machine user read access to its
# private images, which the stamps pull with its token (ADR 0026, ADR 0038).
resource "github_repository_collaborator" "ghcr_reader" {
  for_each   = local.repos
  repository = github_repository.this[each.key].name
  username   = "tl-ghcr-reader"
  permission = "pull"
}

# Environment -> app -> caps, as on each app's SizingCaps tag, so ci.yml checks
# platform.yaml with no sign-in (06-stamp-templates.md section 6.5).
resource "github_actions_variable" "sizing_caps" {
  for_each      = local.repos
  repository    = github_repository.this[each.key].name
  variable_name = "SIZING_CAPS"
  value = jsonencode({
    for d in local.deployments : local.stamps[d.stamp].app_environment => {
      for a in d.apps : a.name => {
        cpu          = a.caps.cpu
        memory       = a.caps.memory
        min_replicas = local.stamps[d.stamp].min_replicas
        max_replicas = a.caps.max_replicas
        profiles     = try(a.caps.profiles, null) != null ? a.caps.profiles : [a.profile]
      }
    } if d.repo == each.key
  })
}

# The stamps' federated credentials trust each repository by its numeric ID
# (ADR 0038, Technical details, Repository IDs for the stamps).
resource "github_actions_environment_variable" "app_repo_ids" {
  for_each      = local.lz_repos
  repository    = "tl-cloud-infrastructure"
  environment   = "lz-${each.key}"
  variable_name = "APP_REPO_IDS"
  value         = jsonencode({ for r in each.value : r => github_repository.this[r].repo_id })
}
