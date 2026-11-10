# One team per product, <tenant>-<product>, with the maintainers of
# catalog/products.yaml, who add and remove its other members themselves. devops
# administers every app repository (11-onboarding.md section 4.3).

data "github_team" "devops" {
  slug = "devops"
}

resource "github_team" "product" {
  for_each    = toset([for r in local.repos : r.team])
  name        = each.key
  description = "The developers of ${each.key}. Its maintainers come from catalog/products.yaml."
  privacy     = "closed"
}

resource "github_team_membership" "maintainer" {
  for_each = merge([
    for r in local.repos : { for m in r.maintainers : "${r.team}/${m}" => { team = r.team, user = m } }
  ]...)
  team_id  = github_team.product[each.value.team].id
  username = each.value.user
  role     = "maintainer"
}

resource "github_team_repository" "product" {
  for_each   = local.repos
  team_id    = github_team.product[each.value.team].id
  repository = github_repository.this[each.key].name
  permission = "push"
}

resource "github_team_repository" "devops" {
  for_each   = local.repos
  team_id    = data.github_team.devops.id
  repository = github_repository.this[each.key].name
  permission = "admin"
}

# The team was named after the product alone, corporate-site. moved keeps the
# team and its membership, and the apply renames the team in place to
# trislab-corporate-site instead of destroying and creating it. The old
# addresses exist only for this one team, so these blocks can be deleted in a
# later PR, once this one is applied.
moved {
  from = github_team.product["corporate-site"]
  to   = github_team.product["trislab-corporate-site"]
}

moved {
  from = github_team_membership.maintainer["corporate-site/tl-janskof"]
  to   = github_team_membership.maintainer["trislab-corporate-site/tl-janskof"]
}
