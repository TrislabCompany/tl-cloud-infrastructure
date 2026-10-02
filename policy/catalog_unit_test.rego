package catalog

owner_list := [
	{"slug": "website-trislab", "kind": "product", "code": "web", "state": "active"},
	{"slug": "construction", "kind": "product", "code": "con", "state": "active"},
	{"slug": "okna-capris", "kind": "customer", "code": "oc", "state": "active"},
	{"slug": "astra-group", "kind": "customer", "code": "asg", "state": "active"},
]

region_list := [
	{"name": "northeurope", "cloud": "azure", "code": "neu", "state": "active"},
	{"name": "italynorth", "cloud": "azure", "code": "itn", "state": "active"},
	{"name": "europe-west8", "cloud": "gcp", "code": "euw8", "state": "active"},
]

# The examples of 07 sections 2, 5, 9, 10 and 11.
good := {
	"owners": owner_list,
	"regions": region_list,
	"repos": [
		{"name": "website-trislab", "product": "website-trislab", "template": "tl-template-spa", "maintainers": ["octo-anna"], "state": "active"},
		{"name": "construction", "product": "construction", "customer": "okna-capris", "template": "tl-template-saas", "maintainers": ["octo-anna", "octo-marko"], "state": "archived", "archived_on": "2026-09-01"},
	],
	"domains": [
		{"name": "trislab.com", "owner": "trislab"},
		{"name": "construction.com", "owner": "trislab"},
		{"name": "astra-group.example", "owner": "astra-group"},
	],
	"tenants": [
		{"name": "website-trislab", "customer": "trislab", "stamp": "products-prod-neu/website-trislab", "hostnames": [
			{"fqdn": "prod-website-trislab.trislab.com", "app": "web"},
			{"fqdn": "trislab.com", "app": "web"},
			{"fqdn": "www.trislab.com", "app": "web"},
		]},
		{"name": "construction", "customer": "trislab", "stamp": "products-prod-neu/construction-shared-01", "hostnames": [
			{"fqdn": "prod-construction-01.trislab.com", "app": "web"},
			{"fqdn": "construction.com", "app": "web"},
		]},
		{"name": "astra-group", "customer": "astra-group", "stamp": "cust-asg-prod-neu/construction", "hostnames": [
			{"fqdn": "prod-construction-astra-group.trislab.com", "app": "web"},
			{"fqdn": "astra-group.example", "app": "web"},
		]},
		{"name": "astra-group", "customer": "astra-group", "stamp": "cust-asg-sandbox-neu/construction-dev"},
	],
	"pools": {"hubs": "10.0.0.0/12", "prod": "10.16.0.0/12", "sandbox": "10.32.0.0/12"},
	"hubs": [{"name": "vnet-hub-neu", "cloud": "azure", "region": "northeurope", "cidr": "10.0.0.0/20", "subnets": {"GatewaySubnet": "10.0.0.0/27"}}],
	"landing_zones": [
		{"name": "products-prod-neu", "cidr": "10.16.0.0/20", "stamps": {"website-trislab": "10.16.0.0/27", "construction-shared-01": "10.16.0.64/26"}},
		{"name": "products-sandbox-neu", "cidr": "10.32.0.0/20", "stamps": {"website-trislab-staging": "10.32.0.0/27"}},
		{"name": "cust-asg-prod-neu", "cidr": "10.16.32.0/20"},
	],
}

with_list(list, entries) := object.union(good, {list: entries})

denied(pr) := d if {
	d := deny with input as {} with data.pr as pr
}

compared(pr, main) := d if {
	d := deny with input as {} with data.pr as pr with data.main as main
}

denies(pr, text) if {
	some msg in denied(pr)
	contains(msg, text)
}

test_good_catalog_passes if {
	count(denied(good)) == 0
}

test_registers_only_pass if {
	count(denied({"owners": [owner_list[0]], "regions": region_list})) == 0
}

test_no_catalog_passes if {
	count(denied({})) == 0
}

# ---- Schema ----

test_list_must_be_a_list if {
	denies(with_list("owners", {"slug": "x"}), "owners must be a list")
}

test_entry_must_be_a_map if {
	denies(with_list("regions", ["northeurope"]), "regions[0] must be a map")
}

test_missing_field_is_denied if {
	denies(with_list("owners", [{"slug": "x", "kind": "customer", "code": "xy"}]), "owners[0] has no state")
}

test_unknown_field_is_denied if {
	denies(with_list("owners", [object.union(owner_list[0], {"name": "Website"})]), "has the unknown field name")
}

test_bad_values_are_denied if {
	denies(with_list("owners", [object.union(owner_list[0], {"kind": "partner"})]), "owners[0].kind is partner")
	denies(with_list("owners", [object.union(owner_list[0], {"code": "webx"})]), "owners[0].code is webx")
	denies(with_list("owners", [object.union(owner_list[0], {"slug": "Website"})]), "owners[0].slug is Website")
	denies(with_list("regions", [object.union(region_list[0], {"cloud": "aws"})]), "regions[0].cloud is aws")
	denies(with_list("regions", [object.union(region_list[0], {"state": "deprecated"})]), "regions[0].state is deprecated")
	denies(with_list("repos", [object.union(good.repos[0], {"template": "tl-template-api"})]), "template is tl-template-api")
	denies(with_list("tenants", [object.union(good.tenants[3], {"stamp": "construction-dev"})]), "stamp is construction-dev")
}

test_bad_cidrs_are_denied if {
	denies(with_list("hubs", [object.union(good.hubs[0], {"cidr": "10.0.0.5/20"})]), "cidr is 10.0.0.5/20")
	denies(with_list("hubs", [object.union(good.hubs[0], {"cidr": "fd00::/20"})]), "cidr is fd00::/20")
	denies(with_list("hubs", [object.union(good.hubs[0], {"cidr": "10.0.0.0/33"})]), "cidr is 10.0.0.0/33")
}

# ---- owner_list.yaml and region_list.yaml ----

test_duplicate_slug_and_code_are_denied if {
	pr := with_list("owners", array.concat(owner_list, [object.union(owner_list[3], {"code": "asx"}), object.union(owner_list[2], {"slug": "okna"})]))
	denies(pr, "the slug astra-group is used more than once")
	denies(pr, "the code oc is used more than once")
}

test_reserved_owner_code_is_denied if {
	denies(with_list("owners", [{"slug": "shared", "kind": "product", "code": "shr", "state": "active"}]), "is a reserved token")
}

test_owner_code_equal_to_region_code_is_denied if {
	denies(with_list("owners", [{"slug": "neutron", "kind": "product", "code": "neu", "state": "active"}]), "is also the code of the region northeurope")
}

test_region_rules if {
	denies(with_list("regions", array.concat(region_list, [{"name": "westeurope", "cloud": "azure", "code": "itn", "state": "active"}])), "the code itn is used more than once")
	denies(with_list("regions", array.concat(region_list, [{"name": "northeurope", "cloud": "azure", "code": "neu2", "state": "active"}])), "the azure region northeurope is listed more than once")
	denies(with_list("regions", [{"name": "westeurope", "cloud": "azure", "code": "prod", "state": "active"}]), "is a reserved token")
}

# ---- repos.yaml ----

test_repo_rules if {
	denies(with_list("repos", [object.union(good.repos[0], {"product": "construction"})]), "the two must be equal")
	denies(with_list("repos", [object.union(good.repos[0], {"name": "hunting", "product": "hunting"})]), "is not a product in catalog/owners.yaml")
	denies(with_list("repos", [object.union(good.repos[0], {"customer": "vbs-lawyers"})]), "is not a customer in catalog/owners.yaml")
	denies(with_list("repos", [object.union(good.repos[0], {"maintainers": []})]), "needs at least one maintainer")
	denies(with_list("repos", [object.union(good.repos[0], {"maintainers": ["-bad-"]})]), "needs at least one maintainer")
	denies(with_list("repos", [object.union(good.repos[0], {"state": "archived"})]), "is archived and has no archived_on")
}

# ---- tenants.yaml ----

test_domain_owner_must_be_customer_or_trislab if {
	denies(with_list("domains", array.concat(good.domains, [{"name": "x.example", "owner": "construction"}])), "the domain x.example has the owner construction")
}

test_tenant_customer_must_be_customer_or_trislab if {
	denies(with_list("tenants", [object.union(good.tenants[1], {"customer": "vbs-lawyers"})]), "has the customer vbs-lawyers")
}

test_tenant_twice_on_a_stamp_is_denied if {
	denies(with_list("tenants", [good.tenants[3], good.tenants[3]]), "is on cust-asg-sandbox-neu/construction-dev more than once")
}

test_tenant_in_customer_landing_zone_must_be_that_customer if {
	denies(with_list("tenants", [object.union(good.tenants[3], {"customer": "okna-capris"})]), "must have the customer whose code is asg")
	denies(with_list("tenants", [object.union(good.tenants[3], {"customer": "trislab"})]), "must have the customer whose code is asg")
}

test_hostname_schema if {
	denies(with_list("tenants", [object.union(good.tenants[3], {"hostnames": [{"fqdn": "Dev.trislab.com", "app": "web"}]})]), "must be { fqdn, app }")
	denies(with_list("tenants", [object.union(good.tenants[3], {"hostnames": [{"fqdn": "dev.trislab.com"}]})]), "must be { fqdn, app }")
}

test_duplicate_hostname_is_denied if {
	t := object.union(good.tenants[3], {"hostnames": [{"fqdn": "trislab.com", "app": "web"}]})
	denies(with_list("tenants", array.concat(good.tenants, [t])), "the hostname trislab.com is used more than once")
}

test_hostname_outside_every_domain_is_denied if {
	t := object.union(good.tenants[3], {"hostnames": [{"fqdn": "dev.astra.example", "app": "web"}]})
	denies(with_list("tenants", [t]), "is in no domain of domains")
}

test_lookalike_domain_is_not_a_match if {
	t := object.union(good.tenants[3], {"hostnames": [{"fqdn": "evilastra-group.example", "app": "web"}]})
	denies(with_list("tenants", [t]), "is in no domain of domains")
}

test_other_customers_domain_is_denied if {
	t := {"name": "okna-capris", "customer": "okna-capris", "stamp": "cust-oc-prod-neu/construction", "hostnames": [{"fqdn": "astra-group.example", "app": "web"}]}
	denies(with_list("tenants", [t]), "which belongs to another customer")
}

test_trislab_domain_serves_any_customer if {
	t := object.union(good.tenants[3], {"hostnames": [{"fqdn": "dev.construction.com", "app": "web"}]})
	count(denied(with_list("tenants", [t]))) == 0
}

test_longest_domain_wins if {
	pr := object.union(good, {
		"domains": array.concat(good.domains, [{"name": "portal.construction.com", "owner": "okna-capris"}]),
		"tenants": [{"name": "okna-capris", "customer": "okna-capris", "stamp": "cust-oc-prod-neu/construction", "hostnames": [{"fqdn": "dev.portal.construction.com", "app": "web"}]}],
	})
	count(denied(pr)) == 0
}

test_hostname_two_labels_below_its_domain_is_denied if {
	t := object.union(good.tenants[3], {"hostnames": [{"fqdn": "dev.portal.trislab.com", "app": "web"}]})
	denies(with_list("tenants", [t]), "is more than one label below trislab.com")
}

# ---- ipam.yaml ----

test_pools_are_fixed if {
	denies(with_list("pools", object.union(good.pools, {"prod": "10.16.0.0/11"})), "pools must be")
	denies(object.remove(good, ["pools"]), "pools must be")
}

test_hub_rules if {
	denies(with_list("hubs", [object.union(good.hubs[0], {"cidr": "10.0.0.0/21", "subnets": {}})]), "must be a /20")
	denies(with_list("hubs", [object.union(good.hubs[0], {"cidr": "10.8.0.0/20", "subnets": {}})]), "must be inside 10.0.0.0/13")
	denies(with_list("hubs", [object.union(good.hubs[0], {"name": "snet-hub-neu"})]), "must be named vnet-hub-<code>")
	denies(with_list("hubs", [object.union(good.hubs[0], {"region": "westeurope"})]), "which is not an active azure region")
	denies(with_list("hubs", [object.union(good.hubs[0], {"name": "vnet-hub-itn"})]), "so its name must end in -hub-neu")
	denies(with_list("hubs", [object.union(good.hubs[0], {"subnets": {"GatewaySubnet": "10.0.0.32/27"}})]), "a /27 at the start of 10.0.0.0/20")
	denies(with_list("hubs", [object.union(good.hubs[0], {"subnets": {"GatewaySubnet": "10.0.0.0/26"}})]), "a /27 at the start of 10.0.0.0/20")
	denies(with_list("hubs", [object.union(good.hubs[0], {"subnets": {"GatewaySubnet": "10.0.0.0/27", "x": "10.0.16.0/27"}})]), "is outside the hub vnet-hub-neu")
}

test_gcp_hub_passes if {
	h := {"name": "snet-hub-euw8", "cloud": "gcp", "region": "europe-west8", "cidr": "10.8.0.0/20"}
	count(denied(with_list("hubs", array.concat(good.hubs, [h])))) == 0
}

test_landing_zone_rules if {
	denies(with_list("landing_zones", [{"name": "cust-oc-nonprod-neu", "cidr": "10.32.16.0/20"}]), "is not a landing zone name")
	denies(with_list("landing_zones", [{"name": "cust-oc-prod-neu", "cidr": "10.16.16.0/21"}]), "must be a /20")
	denies(with_list("landing_zones", [{"name": "cust-oc-prod-neu", "cidr": "10.32.16.0/20"}]), "must be inside the prod pool 10.16.0.0/12")
	denies(with_list("landing_zones", [{"name": "cust-oc-sandbox-neu", "cidr": "10.16.16.0/20"}]), "must be inside the sandbox pool 10.32.0.0/12")
	denies(with_list("landing_zones", [{"name": "cust-oc-prod-neu", "cidr": "10.16.16.0/20", "stamps": {"construction": "10.16.32.0/27"}}]), "is outside the landing zone cust-oc-prod-neu")
}

test_overlapping_ranges_are_denied if {
	denies(with_list("landing_zones", array.concat(good.landing_zones, [{"name": "cust-oc-prod-neu", "cidr": "10.16.0.0/20"}])), "overlaps")
	denies(with_list("landing_zones", [{"name": "products-prod-neu", "cidr": "10.16.0.0/20", "stamps": {"a": "10.16.0.0/27", "b": "10.16.0.0/26"}}]), "a (10.16.0.0/27) overlaps b (10.16.0.0/26)")
	denies(with_list("hubs", [object.union(good.hubs[0], {"subnets": {"GatewaySubnet": "10.0.0.0/27", "x": "10.0.0.16/28"}})]), "overlaps")
}

test_stamp_in_its_landing_zone_is_no_overlap if {
	count([msg | some msg in denied(good); contains(msg, "overlaps")]) == 0
}

# ---- Compared with main ----

test_main_rules_need_main if {
	count(denied({"owners": [], "regions": [], "repos": []})) == 0
}

test_unchanged_registers_pass if {
	count(compared(good, {"owners": owner_list, "regions": region_list, "repos": good.repos})) == 0
}

test_new_entries_pass if {
	count(compared(good, {"owners": [owner_list[0]], "regions": [region_list[0]], "repos": []})) == 0
}

test_retiring_passes if {
	retired := [object.union(o, {"state": "retired"}) | some o in owner_list]
	count(compared(with_list("owners", retired), {"owners": owner_list})) == 0
}

test_removed_owner_is_denied if {
	some msg in compared(with_list("owners", [owner_list[0]]), {"owners": owner_list})
	contains(msg, "okna-capris was removed or renamed")
}

test_renamed_owner_is_denied if {
	pr := with_list("owners", array.concat([object.union(owner_list[0], {"slug": "website"})], array.slice(owner_list, 1, 4)))
	some msg in compared(pr, {"owners": owner_list})
	contains(msg, "website-trislab was removed or renamed")
}

test_changed_owner_code_is_denied if {
	pr := with_list("owners", array.concat([object.union(owner_list[0], {"code": "wbs"})], array.slice(owner_list, 1, 4)))
	some msg in compared(pr, {"owners": owner_list})
	contains(msg, "the code of website-trislab changed from web to wbs")
}

test_removed_region_is_denied if {
	some msg in compared(with_list("regions", [region_list[0], region_list[2]]), {"regions": region_list})
	contains(msg, "the azure region italynorth was removed or renamed")
}

test_changed_region_code_is_denied if {
	pr := with_list("regions", [region_list[0], object.union(region_list[1], {"code": "itno"}), region_list[2]])
	some msg in compared(pr, {"regions": region_list})
	contains(msg, "the code of italynorth changed from itn to itno")
}

test_removed_repo_is_denied if {
	some msg in compared(with_list("repos", [good.repos[0]]), {"repos": good.repos})
	contains(msg, "construction was removed or renamed")
}
