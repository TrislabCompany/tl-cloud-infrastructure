# The free bot settings of the zones whose domain sets bots in
# catalog/domains.yaml (ADR 0060). fight_mode is Bot Fight Mode: it challenges
# or blocks simple bots and scanners. On the Free plan no rule can skip it, so
# the catalog policy refuses it on a zone that serves stamps, whose apps have
# API clients and webhooks. block_ai blocks AI scrapers and crawlers at the
# edge, which enforces what the sites' robots.txt already asks.
#
# Bot Fight Mode needs JavaScript detections (Cloudflare refuses it with
# "cannot enable Fight_Mode while EnableJS is disabled"): a small script from
# the zone's own /cdn-cgi/challenge-platform/, which script-src 'self' allows.
# It also strips ETags from HTML responses.

resource "cloudflare_bot_management" "this" {
  for_each           = { for name, d in local.domains : name => d.bots if try(d.bots, null) != null }
  zone_id            = cloudflare_zone.this[each.key].id
  fight_mode         = try(each.value.fight_mode, false)
  enable_js          = try(each.value.fight_mode, false) ? true : null
  ai_bots_protection = try(each.value.block_ai, false) ? "block" : "disabled"
}
