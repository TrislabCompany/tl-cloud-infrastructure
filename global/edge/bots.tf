# The free bot settings of the zones whose domain sets bots in
# catalog/domains.yaml (ADR 0060). fight_mode is Bot Fight Mode: it challenges
# or blocks simple bots and scanners. On the Free plan no rule can skip it, so
# the catalog policy refuses it on a zone that serves stamps, whose apps have
# API clients and webhooks. block_ai blocks AI scrapers and crawlers at the
# edge, which enforces what the sites' robots.txt already asks.

resource "cloudflare_bot_management" "this" {
  for_each           = { for name, d in local.domains : name => d.bots if try(d.bots, null) != null }
  zone_id            = cloudflare_zone.this[each.key].id
  fight_mode         = try(each.value.fight_mode, false)
  ai_bots_protection = try(each.value.block_ai, false) ? "block" : "disabled"
}
