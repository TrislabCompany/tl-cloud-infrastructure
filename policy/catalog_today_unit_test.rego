# Today's catalog on main, copied here as data in both shapes: the policy must
# not deny it, and a PR that moves it from the old files to the new ones, or
# changes nothing, must pass the comparison with main. The copy is the content
# of catalog/ on main when the new shape was introduced (owners.yaml,
# repos.yaml, tenants.yaml, regions.yaml and ipam.yaml).
package catalog_today_test

regions := [
	{"name": "northeurope", "cloud": "azure", "code": "neu", "state": "active"},
	{"name": "italynorth", "cloud": "azure", "code": "itn", "state": "active"},
	{"name": "europe-west8", "cloud": "gcp", "code": "euw8", "state": "active"},
]

ipam := {
	"pools": {"hubs": "10.0.0.0/12", "prod": "10.16.0.0/12", "sandbox": "10.32.0.0/12"},
	"hubs": [{"name": "vnet-hub-neu", "cloud": "azure", "region": "northeurope", "cidr": "10.0.0.0/20", "subnets": {"GatewaySubnet": "10.0.0.0/27"}}],
	"landing_zones": [
		{"name": "products-sandbox-neu", "cidr": "10.32.0.0/20"},
		{"name": "products-prod-neu", "cidr": "10.16.0.0/20"},
	],
}

redirects := [
	{"from": "www.trislab.com", "to": "trislab.com"},
	{"from": "prod-corporate-site.trislab.com", "to": "trislab.com"},
]

envs := [
	{"name": "dev", "hostname": "dev-corporate-site.trislab.com"},
	{"name": "staging", "hostname": "staging-corporate-site.trislab.com"},
	{"name": "production", "hostname": "trislab.com", "access": "public"},
]

today_old := object.union({"regions": regions}, object.union(ipam, {
	"owners": [
		{"slug": "corporate-site", "kind": "product", "code": "web", "state": "active"},
		{"slug": "dragonja", "kind": "customer", "code": "dra", "state": "active"},
		{"slug": "juskoski", "kind": "customer", "code": "jus", "state": "active"},
		{"slug": "ldistragracisce", "kind": "customer", "code": "ldg", "state": "active"},
		{"slug": "spds", "kind": "customer", "code": "spd", "state": "active"},
	],
	"repos": [{"name": "trislab-website-corporate-site", "product": "corporate-site", "template": "tl-template-website", "maintainers": ["tl-janskof"], "state": "active"}],
	"pages": [{"repo": "trislab-website-corporate-site", "environments": envs}],
	"domains": [
		{"name": "trislab.com", "owner": "trislab", "waf_rate_limit": true, "redirects": redirects},
		{"name": "dragonja.si", "owner": "dragonja"},
		{"name": "juskoski.si", "owner": "juskoski"},
		{"name": "ldistragracisce.si", "owner": "ldistragracisce"},
		{"name": "spds.si", "owner": "spds"},
	],
	"tenants": [],
}))

today_new := object.union({"regions": regions}, object.union(ipam, {
	"tenants": [
		{"slug": "trislab", "state": "active", "products": [{
			"slug": "corporate-site", "code": "web", "repo": "trislab-website-corporate-site", "template": "tl-template-website",
			"maintainers": ["tl-janskof"], "state": "active", "domain": "trislab.com", "environments": envs,
		}]},
		{"slug": "dragonja", "code": "dra", "state": "active", "products": []},
		{"slug": "juskoski", "code": "jus", "state": "active", "products": []},
		{"slug": "ldistragracisce", "code": "ldg", "state": "active", "products": []},
		{"slug": "spds", "code": "spd", "state": "active", "products": []},
	],
	"domains": [
		{"name": "trislab.com", "tenant": "trislab", "waf_rate_limit": true, "redirects": redirects},
		{"name": "dragonja.si", "tenant": "dragonja"},
		{"name": "juskoski.si", "tenant": "juskoski"},
		{"name": "ldistragracisce.si", "tenant": "ldistragracisce"},
		{"name": "spds.si", "tenant": "spds"},
	],
	"stamp_tenants": [],
}))

check(pr, main) := data.catalog.deny with input as {} with data.pr as pr with data.main as main

test_todays_old_catalog_is_not_denied if {
	count(check(today_old, {})) == 0
}

test_todays_new_catalog_is_not_denied if {
	count(check(today_new, {})) == 0
}

test_old_to_old_changes_nothing if {
	count(check(today_old, today_old)) == 0
}

test_old_to_new_moves_nothing if {
	count(check(today_new, today_old)) == 0
}

test_new_to_new_changes_nothing if {
	count(check(today_new, today_new)) == 0
}

# The move does not skip the comparison: dropping an owner or the repository is still denied.
test_old_to_new_without_the_repository_is_denied if {
	pr := object.union(today_new, {"tenants": [
		{"slug": "trislab", "state": "active", "products": []},
		{"slug": "dragonja", "code": "dra", "state": "active", "products": []},
		{"slug": "juskoski", "code": "jus", "state": "active", "products": []},
		{"slug": "ldistragracisce", "code": "ldg", "state": "active", "products": []},
		{"slug": "spds", "code": "spd", "state": "active", "products": []},
	]})
	some msg in check(pr, today_old)
	contains(msg, "the repository trislab-website-corporate-site was removed or renamed")
	some msg2 in check(pr, today_old)
	contains(msg2, "corporate-site was removed or renamed; an owner is retired")
}
