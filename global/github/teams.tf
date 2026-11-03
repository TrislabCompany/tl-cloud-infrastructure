# One team per product, with the maintainers of catalog/repos.yaml, who add
# and remove its other members themselves. devops administers every app
# repository (11-onboarding.md section 4.3).

data "github_team" "devops" {
  slug = "devops"
}

resource "github_team" "product" {
  for_each    = toset([for r in local.repos : r.product])
  name        = each.key
  description = "The developers of ${each.key}. Its maintainers come from catalog/repos.yaml."
  privacy     = "closed"
}

resource "github_team_membership" "maintainer" {
  for_each = merge([
    for r in local.repos : { for m in r.maintainers : "${r.product}/${m}" => { team = r.product, user = m } }
  ]...)
  team_id  = github_team.product[each.value.team].id
  username = each.value.user
  role     = "maintainer"
}

resource "github_team_repository" "product" {
  for_each   = local.repos
  team_id    = github_team.product[each.value.product].id
  repository = github_repository.this[each.key].name
  permission = "push"
}

resource "github_team_repository" "devops" {
  for_each   = local.repos
  team_id    = data.github_team.devops.id
  repository = github_repository.this[each.key].name
  permission = "admin"
}
