# The rules of catalog.rego against the new catalog shape (products.yaml and
# domains.yaml), and the comparison with main for old to new and new to new. The
# old shape is in catalog_unit_test.rego.
package catalog_new_test

region_list := [
	{"name": "northeurope", "cloud": "azure", "code": "neu", "state": "active"},
	{"name": "italynorth", "cloud": "azure", "code": "itn", "state": "active"},
	{"name": "europe-west8", "cloud": "gcp", "code": "euw8", "state": "active"},
]

corporate_site := {"slug": "corporate-site", "code": "web", "repo": "trislab-website-corporate-site", "template": "tl-template-website", "maintainers": ["octo-anna"], "state": "active", "domain": "trislab.com"}

construction_product := {"slug": "construction", "code": "con", "repo": "trislab-saas-construction", "template": "tl-template-saas", "maintainers": ["octo-anna", "octo-marko"], "state": "active", "domain": "construction.com"}

# catalog/products.yaml: trislab has no code, a client tenant has one, and a
# product has one only when a stamp deploys it. construction is a product of
# trislab and, archived, of okna-capris: a slug is unique within its tenant.
tenant_list := [
	{"slug": "trislab", "state": "active", "products": [corporate_site, construction_product]},
	{"slug": "okna-capris", "code": "oc", "state": "active", "products": [
		{"slug": "construction", "repo": "okna-capris-webapp-construction", "template": "tl-template-webapp", "maintainers": ["octo-marko"], "state": "archived", "archived_on": "2026-09-01", "domain": "okna-capris.example"},
	]},
	{"slug": "astra-group", "code": "asg", "state": "active", "products": []},
]

# The owners the old catalog/owners.yaml listed for tenant_list.
owner_list := [
	{"slug": "corporate-site", "kind": "product", "code": "web", "state": "active"},
	{"slug": "construction", "kind": "product", "code": "con", "state": "active"},
	{"slug": "okna-capris", "kind": "customer", "code": "oc", "state": "active"},
	{"slug": "astra-group", "kind": "customer", "code": "asg", "state": "active"},
]

# The examples of 07 sections 2, 5, 9, 10 and 11.
good := {
	"tenants": tenant_list,
	"regions": region_list,
	"domains": [
		{"name": "trislab.com", "tenant": "trislab", "redirects": [{"from": "www.trislab.com", "to": "trislab.com"}]},
		{"name": "construction.com", "tenant": "trislab"},
		{"name": "astra-group.example", "tenant": "astra-group"},
		{"name": "okna-capris.example", "tenant": "okna-capris"},
	],
	"stamp_tenants": [
		{"name": "corporate-site", "customer": "trislab", "stamp": "products-prod-neu/corporate-site", "hostnames": [
			{"fqdn": "prod-corporate-site.trislab.com", "app": "web", "access": "protected"},
			{"fqdn": "trislab.com", "app": "web"},
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
		{"name": "products-prod-neu", "cidr": "10.16.0.0/20", "stamps": {"corporate-site": "10.16.0.0/27", "construction-shared-01": "10.16.0.64/26"}},
		{"name": "products-sandbox-neu", "cidr": "10.32.0.0/20", "stamps": {"corporate-site-staging": "10.32.0.0/27"}},
		{"name": "cust-asg-prod-neu", "cidr": "10.16.32.0/20"},
	],
	"stamp_yaml": {
		"products-prod-neu/corporate-site": stamp("corporate-site", "trislab-website-corporate-site"),
		"products-prod-neu/construction-shared-01": stamp("construction", "trislab-saas-construction"),
		"cust-asg-prod-neu/construction": stamp("construction", "trislab-saas-construction"),
		"cust-asg-sandbox-neu/construction-dev": stamp("construction", "trislab-saas-construction"),
		"cust-oc-prod-neu/construction": stamp("construction", "trislab-saas-construction"),
	},
}

# The fields of a stamp.yaml that the rules read.
stamp(product, repo) := {"template": "aca-app", "version": "v1.0.0", "product": product, "apps": [
	{"name": "web", "repo": repo, "ingress": "external", "port": 8080},
	{"name": "worker", "repo": repo, "ingress": "none"},
]}

with_stamp(key, s) := object.union(good, {"stamp_yaml": object.union(good.stamp_yaml, {key: s})})

with_list(list, entries) := object.union(good, {list: entries})

denied(pr) := d if {
	d := data.catalog.deny with input as {} with data.pr as pr
}

compared(pr, main) := d if {
	d := data.catalog.deny with input as {} with data.pr as pr with data.main as main
}

denies(pr, text) if {
	some msg in denied(pr)
	contains(msg, text)
}

test_good_catalog_passes if {
	count(denied(good)) == 0
}

test_registers_only_pass if {
	count(denied({"tenants": [tenant_list[2]], "regions": region_list})) == 0
}

test_no_catalog_passes if {
	count(denied({})) == 0
}

# ---- Schema ----

test_list_must_be_a_list if {
	denies(with_list("tenants", {"slug": "x"}), "tenants must be a list")
}

test_entry_must_be_a_map if {
	denies(with_list("regions", ["northeurope"]), "regions[0] must be a map")
	denies(with_list("tenants", ["trislab"]), "tenants[0] must be a map")
}

test_missing_field_is_denied if {
	denies(with_list("tenants", [{"slug": "x", "code": "xy", "products": []}]), "tenants[0] has no state")
	denies(with_list("tenants", [{"slug": "x", "code": "xy", "state": "active"}]), "tenants[0] has no products")
	denies(trislab_with([object.remove(corporate_site, ["domain"])]), "products[0] has no domain")
}

test_unknown_field_is_denied if {
	denies(with_list("tenants", [object.union(tenant_list[1], {"name": "Okna"})]), "has the unknown field name")
	denies(trislab_with([object.union(corporate_site, {"customer": "trislab"})]), "has the unknown field customer")
}

test_bad_values_are_denied if {
	denies(with_list("tenants", [object.union(tenant_list[1], {"code": "okna"})]), "tenants[0].code is okna")
	denies(with_list("tenants", [object.union(tenant_list[1], {"slug": "Okna"})]), "tenants[0].slug is Okna")
	denies(with_list("tenants", [object.union(tenant_list[1], {"state": "archived"})]), "tenants[0].state is archived")
	denies(trislab_with([object.union(corporate_site, {"code": "webx"})]), "products[0].code is webx")
	denies(trislab_with([object.union(corporate_site, {"state": "retired"})]), "products[0].state is retired")
	denies(trislab_with([object.union(corporate_site, {"template": "tl-template-api"})]), "template is tl-template-api")
	denies(trislab_with([object.union(corporate_site, {"template": "tl-template-spa"})]), "template is tl-template-spa")
	denies(trislab_with([object.union(corporate_site, {"domain": "Trislab.com"})]), "products[0].domain is Trislab.com")
	denies(with_list("regions", [object.union(region_list[0], {"cloud": "aws"})]), "regions[0].cloud is aws")
	denies(with_list("regions", [object.union(region_list[0], {"state": "deprecated"})]), "regions[0].state is deprecated")
	denies(with_list("stamp_tenants", [object.union(good.stamp_tenants[3], {"stamp": "construction-dev"})]), "stamp is construction-dev")
}

test_bad_cidrs_are_denied if {
	denies(with_list("hubs", [object.union(good.hubs[0], {"cidr": "10.0.0.5/20"})]), "cidr is 10.0.0.5/20")
	denies(with_list("hubs", [object.union(good.hubs[0], {"cidr": "fd00::/20"})]), "cidr is fd00::/20")
	denies(with_list("hubs", [object.union(good.hubs[0], {"cidr": "10.0.0.0/33"})]), "cidr is 10.0.0.0/33")
}

# ---- products.yaml and regions.yaml ----

trislab_with(products) := with_list("tenants", [object.union(tenant_list[0], {"products": products}), tenant_list[1], tenant_list[2]])

test_duplicate_tenant_slug_and_codes_are_denied if {
	pr := with_list("tenants", array.concat(tenant_list, [object.union(tenant_list[2], {"code": "asx"}), object.union(tenant_list[1], {"slug": "okna"})]))
	denies(pr, "the slug astra-group is used more than once")
	denies(pr, "the code oc is used by more than one product or client tenant")
}

test_product_code_is_shared_with_the_owners if {
	denies(trislab_with([corporate_site, object.union(construction_product, {"code": "web"})]), "the code web is used by more than one product or client tenant")
	denies(trislab_with([corporate_site, object.union(construction_product, {"code": "oc"})]), "the code oc is used by more than one product or client tenant")
	denies(trislab_with([corporate_site, object.union(construction_product, {"slug": "okna-capris", "repo": "trislab-saas-okna-capris"})]), "the slug okna-capris is used by more than one")
}

test_reserved_owner_code_is_denied if {
	denies(trislab_with([object.union(corporate_site, {"code": "shr"})]), "is a reserved token")
	denies(with_list("tenants", [object.union(tenant_list[1], {"code": "sb"})]), "is a reserved token")
}

test_owner_code_equal_to_region_code_is_denied if {
	denies(trislab_with([object.union(corporate_site, {"code": "neu"})]), "is also the code of the region northeurope")
}

test_region_rules if {
	denies(with_list("regions", array.concat(region_list, [{"name": "westeurope", "cloud": "azure", "code": "itn", "state": "active"}])), "the code itn is used more than once")
	denies(with_list("regions", array.concat(region_list, [{"name": "northeurope", "cloud": "azure", "code": "neu2", "state": "active"}])), "the azure region northeurope is listed more than once")
	denies(with_list("regions", [{"name": "westeurope", "cloud": "azure", "code": "prod", "state": "active"}]), "is a reserved token")
}

# ---- products.yaml, tenants and products ----

test_trislab_has_no_code_and_a_client_has_one if {
	denies(with_list("tenants", [object.remove(tenant_list[1], ["code"])]), "the tenant okna-capris has no code")
	denies(with_list("tenants", [object.union(tenant_list[0], {"code": "trl"})]), "the tenant trislab is the platform's own owner and has no code, not trl")
	count(denied(good)) == 0
}

test_product_rules if {
	denies(trislab_with([object.union(corporate_site, {"repo": "corporate-site"})]), "corporate-site must be named trislab-website-corporate-site")
	denies(trislab_with([object.union(corporate_site, {"slug": "hunting"})]), "must be named trislab-website-hunting")
	denies(trislab_with([object.union(corporate_site, {"template": "tl-template-saas"})]), "must be named trislab-saas-corporate-site")
	denies(with_list("tenants", [tenant_list[0], object.union(tenant_list[1], {"products": [object.union(tenant_list[1].products[0], {"repo": "trislab-webapp-construction"})]}), tenant_list[2]]), "must be named okna-capris-webapp-construction")
	denies(trislab_with([object.union(corporate_site, {"maintainers": []})]), "needs at least one maintainer")
	denies(trislab_with([object.union(corporate_site, {"maintainers": ["-bad-"]})]), "needs at least one maintainer")
	denies(trislab_with([object.union(corporate_site, {"state": "archived"})]), "is archived and has no archived_on")
}

test_product_slug_is_unique_within_its_tenant_only if {
	denies(trislab_with([corporate_site, corporate_site]), "the tenant trislab has the product corporate-site more than once")
	# construction is a product of two tenants.
	count([msg | some msg in denied(good); contains(msg, "more than once")]) == 0
}

test_repository_is_unique if {
	denies(trislab_with([corporate_site, object.union(corporate_site, {"slug": "other-site", "code": "xyz"})]), "the repo trislab-website-corporate-site is used more than once")
}

test_code_is_required_only_when_a_stamp_deploys_the_product if {
	denies(trislab_with([object.remove(corporate_site, ["code"]), construction_product]), "the product corporate-site of trislab has no code, which a product needs once a stamp deploys from its repository")
	# The archived product of okna-capris has no code and no stamp deploys it.
	count(denied(good)) == 0
}

test_product_domain_must_exist_and_belong_to_its_tenant if {
	denies(trislab_with([object.union(corporate_site, {"domain": "nowhere.example"})]), "names the domain nowhere.example, which is not in catalog/domains.yaml")
	denies(trislab_with([object.union(corporate_site, {"domain": "astra-group.example"})]), "is on the domain astra-group.example, which belongs to the tenant astra-group")
}

# ---- domains.yaml ----

test_domain_tenant_must_be_a_tenant if {
	denies(with_list("domains", array.concat(good.domains, [{"name": "x.example", "tenant": "construction"}])), "the domain x.example has the tenant construction")
}

test_domain_waf_rate_limit_is_a_boolean if {
	on := [object.union(good.domains[0], {"waf_rate_limit": true})]
	count(denied(with_list("domains", array.concat(on, array.slice(good.domains, 1, count(good.domains)))))) == 0
	denies(with_list("domains", array.concat([object.union(good.domains[0], {"waf_rate_limit": "yes"})], array.slice(good.domains, 1, count(good.domains)))), "waf_rate_limit is yes, which is not allowed")
}

test_stamp_tenant_customer_must_be_a_tenant if {
	denies(with_list("stamp_tenants", [object.union(good.stamp_tenants[1], {"customer": "vbs-lawyers"})]), "has the customer vbs-lawyers")
}

test_tenant_twice_on_a_stamp_is_denied if {
	denies(with_list("stamp_tenants", [good.stamp_tenants[3], good.stamp_tenants[3]]), "is on cust-asg-sandbox-neu/construction-dev more than once")
}

test_tenant_in_customer_landing_zone_must_be_that_customer if {
	denies(with_list("stamp_tenants", [object.union(good.stamp_tenants[3], {"customer": "okna-capris"})]), "must have the customer whose code is asg")
	denies(with_list("stamp_tenants", [object.union(good.stamp_tenants[3], {"customer": "trislab"})]), "must have the customer whose code is asg")
}

test_hostname_schema if {
	denies(with_list("stamp_tenants", [object.union(good.stamp_tenants[3], {"hostnames": [{"fqdn": "Dev.trislab.com", "app": "web"}]})]), "must be { fqdn, app }")
	denies(with_list("stamp_tenants", [object.union(good.stamp_tenants[3], {"hostnames": [{"fqdn": "dev.trislab.com"}]})]), "must be { fqdn, app }")
	denies(with_list("stamp_tenants", [object.union(good.stamp_tenants[3], {"hostnames": [{"fqdn": "dev.trislab.com", "app": "web", "access": "private"}]})]), "must be { fqdn, app }")
	denies(with_list("stamp_tenants", [object.union(good.stamp_tenants[3], {"hostnames": [{"fqdn": "dev.trislab.com", "app": "web", "tls": "strict"}]})]), "must be { fqdn, app }")
}

test_hostname_access if {
	sandbox_protected := object.union(good.stamp_tenants[3], {"hostnames": [{"fqdn": "dev.trislab.com", "app": "web", "access": "protected"}]})
	count(denied(with_list("stamp_tenants", [sandbox_protected]))) == 0

	prod_public := object.union(good.stamp_tenants[0], {"hostnames": [{"fqdn": "trislab.com", "app": "web", "access": "public"}]})
	count(denied(with_list("stamp_tenants", [prod_public]))) == 0

	sandbox_public := object.union(good.stamp_tenants[3], {"hostnames": [{"fqdn": "dev.trislab.com", "app": "web", "access": "public"}]})
	denies(with_list("stamp_tenants", [sandbox_public]), "is in a sandbox landing zone, which is always protected")
}

test_duplicate_hostname_is_denied if {
	t := object.union(good.stamp_tenants[3], {"hostnames": [{"fqdn": "trislab.com", "app": "web"}]})
	denies(with_list("stamp_tenants", array.concat(good.stamp_tenants, [t])), "the hostname trislab.com is used more than once")
}

test_hostname_outside_every_domain_is_denied if {
	t := object.union(good.stamp_tenants[3], {"hostnames": [{"fqdn": "dev.astra.example", "app": "web"}]})
	denies(with_list("stamp_tenants", [t]), "is in no domain of domains")
}

test_lookalike_domain_is_not_a_match if {
	t := object.union(good.stamp_tenants[3], {"hostnames": [{"fqdn": "evilastra-group.example", "app": "web"}]})
	denies(with_list("stamp_tenants", [t]), "is in no domain of domains")
}

test_other_customers_domain_is_denied if {
	t := {"name": "okna-capris", "customer": "okna-capris", "stamp": "cust-oc-prod-neu/construction", "hostnames": [{"fqdn": "astra-group.example", "app": "web"}]}
	denies(with_list("stamp_tenants", [t]), "which belongs to another customer")
}

test_trislab_domain_serves_any_customer if {
	t := object.union(good.stamp_tenants[3], {"hostnames": [{"fqdn": "dev.construction.com", "app": "web"}]})
	count(denied(with_list("stamp_tenants", [t]))) == 0
}

test_longest_domain_wins if {
	pr := object.union(good, {
		"domains": array.concat(good.domains, [{"name": "portal.construction.com", "tenant": "okna-capris"}]),
		"stamp_tenants": [{"name": "okna-capris", "customer": "okna-capris", "stamp": "cust-oc-prod-neu/construction", "hostnames": [{"fqdn": "dev.portal.construction.com", "app": "web"}]}],
	})
	count(denied(pr)) == 0
}

test_hostname_two_labels_below_its_domain_is_denied if {
	t := object.union(good.stamp_tenants[3], {"hostnames": [{"fqdn": "dev.portal.trislab.com", "app": "web"}]})
	denies(with_list("stamp_tenants", [t]), "is more than one label below trislab.com")
}

# ---- stamp.yaml ----

test_tenant_on_a_stamp_without_stamp_yaml_is_denied if {
	denies(with_list("stamp_tenants", [object.union(good.stamp_tenants[3], {"stamp": "cust-asg-sandbox-neu/construction-test"})]), "which has no stamps/cust-asg-sandbox-neu/construction-test/stamp.yaml")
}

test_hostname_app_must_be_an_external_app_of_the_stamp if {
	denies(with_list("stamp_tenants", [object.union(good.stamp_tenants[3], {"hostnames": [{"fqdn": "dev.trislab.com", "app": "api"}]})]), "names the app api, which is not an app of the stamp")
	denies(with_list("stamp_tenants", [object.union(good.stamp_tenants[3], {"hostnames": [{"fqdn": "dev.trislab.com", "app": "worker"}]})]), "names the app worker, which is not an app of the stamp")
	internal := stamp("construction", "trislab-saas-construction")
	no_ingress := {"product": "construction", "apps": [{"name": "web", "repo": "trislab-saas-construction", "port": 8080}]}
	denies(with_stamp("products-prod-neu/construction-shared-01", object.union(internal, {"apps": [object.union(internal.apps[0], {"ingress": "internal"})]})), "names the app web, which is not an app of the stamp with ingress: external")
	denies(with_stamp("products-prod-neu/construction-shared-01", no_ingress), "names the app web, which is not an app of the stamp with ingress: external")
}

test_app_repo_must_be_an_active_repository if {
	denies(with_stamp("products-sandbox-neu/construction-dev", stamp("construction", "trislab-saas-hunting")), "deploys from trislab-saas-hunting, which is not an active product repository")
	denies(with_stamp("products-sandbox-neu/construction-dev", stamp("construction", "okna-capris-webapp-construction")), "deploys from okna-capris-webapp-construction, which is not an active product repository")
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

test_managed_stamp_takes_no_range if {
	managed := object.union(stamp("corporate-site", "trislab-website-corporate-site"), {"network": {"mode": "managed"}})
	denies(with_stamp("products-sandbox-neu/corporate-site-staging", managed), "the stamp products-sandbox-neu/corporate-site-staging has network.mode managed, so it takes no range")
	count([msg | some msg in denied(with_stamp("products-sandbox-neu/corporate-site-dev", managed)); contains(msg, "network.mode managed")]) == 0
	vnet := object.union(stamp("corporate-site", "trislab-website-corporate-site"), {"network": {"subnet_cidr": "10.32.0.0/27"}})
	count([msg | some msg in denied(with_stamp("products-sandbox-neu/corporate-site-staging", vnet)); contains(msg, "network.mode managed")]) == 0
}

test_stamp_in_its_landing_zone_is_no_overlap if {
	count([msg | some msg in denied(good); contains(msg, "overlaps")]) == 0
}

# ---- Compared with main ----

# main's catalog before catalog/products.yaml: owners.yaml, repos.yaml and
# tenants.yaml (whose tenants are stamp tenants, and whose domains have an owner).
old_repos := [
	{"name": "trislab-website-corporate-site", "product": "corporate-site", "template": "tl-template-website", "maintainers": ["octo-anna"], "state": "active"},
	{"name": "trislab-saas-construction", "product": "construction", "template": "tl-template-saas", "maintainers": ["octo-anna", "octo-marko"], "state": "active"},
	{"name": "okna-capris-webapp-construction", "product": "construction", "customer": "okna-capris", "template": "tl-template-webapp", "maintainers": ["octo-marko"], "state": "archived", "archived_on": "2026-09-01"},
]

old_domains := [{"name": d.name, "owner": d.tenant} | some d in good.domains]

old_main := {"owners": owner_list, "regions": region_list, "repos": old_repos, "tenants": good.stamp_tenants, "domains": old_domains}

test_main_rules_need_main if {
	count(denied({"tenants": [], "regions": []})) == 0
}

test_unchanged_catalog_passes if {
	count(compared(good, {"tenants": tenant_list, "regions": region_list, "domains": good.domains, "stamp_tenants": good.stamp_tenants})) == 0
}

# The PR that moves to products.yaml and domains.yaml: main still has the old files.
test_move_from_the_old_files_passes if {
	count(compared(good, old_main)) == 0
}

test_move_from_the_old_files_is_still_compared if {
	main := object.union(old_main, {"owners": array.concat(owner_list, [{"slug": "hunting", "kind": "customer", "code": "hun", "state": "active"}])})
	some msg in compared(good, main)
	contains(msg, "hunting was removed or renamed")
	main2 := object.union(old_main, {"repos": array.concat(old_repos, [{"name": "trislab-saas-hunting", "product": "construction", "template": "tl-template-saas", "maintainers": ["a"], "state": "active"}])})
	some msg2 in compared(good, main2)
	contains(msg2, "the repository trislab-saas-hunting was removed or renamed")
	main3 := object.union(old_main, {"owners": array.concat([object.union(owner_list[0], {"code": "wbs"})], array.slice(owner_list, 1, 4))})
	some msg3 in compared(good, main3)
	contains(msg3, "the code of corporate-site changed from wbs to web")
}

test_new_entries_pass if {
	count(compared(good, {"tenants": [object.union(tenant_list[0], {"products": [corporate_site]})], "regions": [region_list[0]]})) == 0
	count(compared(good, {"owners": [owner_list[0]], "regions": [region_list[0]], "repos": []})) == 0
}

test_retiring_passes if {
	retired := [object.union(t, {"state": "retired"}) | some t in tenant_list]
	count(compared(with_list("tenants", retired), {"tenants": tenant_list})) == 0
}

test_removed_tenant_is_denied if {
	pr := with_list("tenants", [tenant_list[0], tenant_list[1]])
	some msg in compared(pr, {"tenants": tenant_list})
	contains(msg, "the tenant astra-group was removed or renamed")
	some msg2 in compared(pr, {"tenants": tenant_list})
	contains(msg2, "astra-group was removed or renamed; an owner is retired")
}

test_removed_product_is_denied if {
	pr := trislab_with([corporate_site])
	some msg in compared(pr, {"tenants": tenant_list})
	contains(msg, "the product construction of trislab was removed or renamed")
	some msg2 in compared(pr, {"tenants": tenant_list})
	contains(msg2, "the repository trislab-saas-construction was removed or renamed")
}

# main's owners before step A8 renames website-trislab to corporate-site.
renamed_owners := array.concat([object.union(owner_list[0], {"slug": "website-trislab"})], array.slice(owner_list, 1, 4))

test_renaming_an_unreferenced_owner_passes if {
	count(compared(good, {"owners": renamed_owners})) == 0
	count(compared(good, {"owners": renamed_owners, "repos": [old_repos[1]], "stamp_yaml": {"x/y": stamp("construction", "z")}})) == 0
}

test_renaming_a_referenced_owner_is_denied if {
	some msg in compared(good, {"owners": renamed_owners, "stamp_yaml": {"products-prod-neu/website-trislab": stamp("website-trislab", "website-trislab")}})
	contains(msg, "website-trislab was removed or renamed")
	some msg2 in compared(good, {"owners": renamed_owners, "repos": [object.union(old_repos[0], {"name": "website-trislab", "product": "website-trislab"})]})
	contains(msg2, "website-trislab was removed or renamed")
}

test_renaming_a_referenced_customer_is_denied if {
	main := array.concat(array.slice(owner_list, 0, 3), [object.union(owner_list[3], {"slug": "astra"})])
	some msg in compared(good, {"owners": main, "tenants": [object.union(good.stamp_tenants[3], {"customer": "astra"})]})
	contains(msg, "astra was removed or renamed")
	some msg2 in compared(good, {"owners": main, "domains": [{"name": "astra-group.example", "owner": "astra"}]})
	contains(msg2, "astra was removed or renamed")
	some msg3 in compared(good, {"owners": main, "repos": [object.union(old_repos[2], {"customer": "astra"})]})
	contains(msg3, "astra was removed or renamed")
	some msg4 in compared(good, {"owners": main, "lz_yaml": {"cust-asg-prod-neu": {"name": "cust-asg-prod-neu"}}})
	contains(msg4, "astra was removed or renamed")
	some msg5 in compared(good, {"owners": main, "domains": [{"name": "astra-group.example", "tenant": "astra"}]})
	contains(msg5, "astra was removed or renamed")
}

test_renamed_owner_with_another_code_is_denied if {
	pr := trislab_with([object.union(corporate_site, {"code": "wbs"}), construction_product])
	some msg in compared(pr, {"owners": renamed_owners})
	contains(msg, "website-trislab was removed or renamed")
}

test_reused_code_is_denied if {
	main := array.concat([object.union(renamed_owners[0], {"state": "retired"})], array.slice(owner_list, 1, 4))
	some msg in compared(good, {"owners": main})
	contains(msg, "corporate-site takes the code web of website-trislab on main")
	some msg2 in compared(good, {"owners": renamed_owners, "repos": [object.union(old_repos[0], {"name": "website-trislab", "product": "website-trislab"})]})
	contains(msg2, "corporate-site takes the code web of website-trislab on main")
}

test_changed_owner_code_is_denied if {
	pr := trislab_with([object.union(corporate_site, {"code": "wbs"}), construction_product])
	some msg in compared(pr, {"owners": owner_list})
	contains(msg, "the code of corporate-site changed from web to wbs")
	some msg2 in compared(pr, {"tenants": tenant_list})
	contains(msg2, "the code of corporate-site changed from web to wbs")
}

test_changed_tenant_code_is_denied if {
	pr := with_list("tenants", [tenant_list[0], object.union(tenant_list[1], {"code": "okn"}), tenant_list[2]])
	some msg in compared(pr, {"tenants": tenant_list})
	contains(msg, "the code of okna-capris changed from oc to okn")
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
	some msg in compared(trislab_with([corporate_site]), {"repos": old_repos})
	contains(msg, "construction was removed or renamed")
}

# ---- landing-zones/<lz>.yaml ----

lz(name, extra) := object.union({"name": name, "state": "active"}, extra)

test_production_data_in_prod_passes if {
	count(compared({"lz_yaml": {"products-prod-neu": lz("products-prod-neu", {"production_data": true})}}, {})) == 0
}

test_production_data_in_sandbox_is_denied if {
	some msg in denied({"lz_yaml": {"products-sandbox-neu": lz("products-sandbox-neu", {"production_data": false})}})
	contains(msg, "landing-zones/products-sandbox-neu.yaml: production_data is set only in a prod landing zone")
}

test_production_data_stays_true_passes if {
	y := {"cust-oc-prod-neu": lz("cust-oc-prod-neu", {"production_data": true})}
	count(compared({"lz_yaml": y}, {"lz_yaml": y})) == 0
}

test_production_data_set_back_to_false_is_denied if {
	pr := {"lz_yaml": {"cust-oc-prod-neu": lz("cust-oc-prod-neu", {"production_data": false})}}
	some msg in compared(pr, {"lz_yaml": {"cust-oc-prod-neu": lz("cust-oc-prod-neu", {"production_data": true})}})
	contains(msg, "production_data was true on main; it never goes back to false")
}

test_production_data_removed_is_denied if {
	pr := {"lz_yaml": {"cust-oc-prod-neu": lz("cust-oc-prod-neu", {})}}
	some msg in compared(pr, {"lz_yaml": {"cust-oc-prod-neu": lz("cust-oc-prod-neu", {"production_data": true})}})
	contains(msg, "production_data was true on main; it never goes back to false")
}

test_name_not_file_name_is_denied if {
	some msg in denied({"lz_yaml": {"products-sandbox-neu": lz("products-prod-neu", {})}})
	contains(msg, "landing-zones/products-sandbox-neu.yaml: name is products-prod-neu; it must be the file name")
}

hub_neu := {"name": "vnet-hub-neu", "cloud": "azure", "region": "northeurope", "cidr": "10.0.0.0/20"}

test_landing_zone_in_a_hub_region_passes if {
	y := {"products-sandbox-neu": lz("products-sandbox-neu", {"cloud": "azure", "region": "northeurope"})}
	not denies({"hubs": [hub_neu], "lz_yaml": y}, "there is no")
}

test_landing_zone_without_a_hub_is_denied if {
	y := {"products-sandbox-itn": lz("products-sandbox-itn", {"cloud": "azure", "region": "italynorth"})}
	denies({"hubs": [hub_neu], "lz_yaml": y}, "landing-zones/products-sandbox-itn.yaml: there is no azure hub in italynorth in catalog/ipam.yaml")
}

test_new_experiment_ttl_90_passes if {
	count(compared({"lz_yaml": {"exp-aks": lz("exp-aks", {"archetype": "experiment", "ttl": "90d"})}}, {})) == 0
}

test_new_experiment_ttl_over_90_is_denied if {
	some msg in compared({"lz_yaml": {"exp-aks": lz("exp-aks", {"archetype": "experiment", "ttl": "91d"})}}, {})
	contains(msg, "a new experiment's ttl is at most 90d")
}

test_extended_experiment_ttl_passes if {
	main := {"lz_yaml": {"exp-aks": lz("exp-aks", {"archetype": "experiment", "ttl": "90d"})}}
	count(compared({"lz_yaml": {"exp-aks": lz("exp-aks", {"archetype": "experiment", "ttl": "150d"})}}, main)) == 0
}

test_decommissioned_on_not_a_date_is_denied if {
	some msg in denied({"lz_yaml": {"exp-aks": lz("exp-aks", {"state": "decommissioned", "decommissioned_on": "1.11.2026"})}})
	contains(msg, "decommissioned_on must be a date")
}

decommissioned(name, on, extra) := lz(name, object.union({"state": "decommissioned", "decommissioned_on": on}, extra))

test_cancel_after_hold_passes if {
	main := {"lz_yaml": {"exp-aks": decommissioned("exp-aks", "2020-01-01", {})}}
	count(compared({"lz_yaml": {"exp-aks": decommissioned("exp-aks", "2020-01-01", {"state": "cancelled"})}}, main)) == 0
}

test_cancel_during_hold_is_denied if {
	main := {"lz_yaml": {"products-sandbox-neu": decommissioned("products-sandbox-neu", "2200-01-01", {})}}
	some msg in compared({"lz_yaml": {"products-sandbox-neu": decommissioned("products-sandbox-neu", "2200-01-01", {"state": "cancelled"})}}, main)
	contains(msg, "the hold ends on 2200-01-02")
}

test_experiment_hold_is_0_days if {
	main := {"lz_yaml": {"exp-aks": decommissioned("exp-aks", "2200-01-01", {})}}
	some msg in compared({"lz_yaml": {"exp-aks": decommissioned("exp-aks", "2200-01-01", {"state": "cancelled"})}}, main)
	contains(msg, "the hold ends on 2200-01-01")
}

test_hold_days_count_from_main if {
	main := {"lz_yaml": {"exp-aks": decommissioned("exp-aks", "2200-01-01", {"hold_days": 3})}}
	some msg in compared({"lz_yaml": {"exp-aks": decommissioned("exp-aks", "2200-01-01", {"state": "cancelled", "hold_days": 0})}}, main)
	contains(msg, "the hold ends on 2200-01-04")
}

test_cancel_from_active_is_denied if {
	main := {"lz_yaml": {"exp-aks": lz("exp-aks", {})}}
	some msg in compared({"lz_yaml": {"exp-aks": decommissioned("exp-aks", "2020-01-01", {"state": "cancelled"})}}, main)
	contains(msg, "state cancelled follows decommissioned on main")
}

test_cancel_from_active_with_hold_days_0_passes if {
	main := {"lz_yaml": {"products-sandbox-neu": lz("products-sandbox-neu", {})}}
	count(compared({"lz_yaml": {"products-sandbox-neu": decommissioned("products-sandbox-neu", "2200-01-01", {"state": "cancelled", "hold_days": 0})}}, main)) == 0
}

test_cancel_from_active_without_hold_days_0_is_denied if {
	main := {"lz_yaml": {"products-sandbox-neu": lz("products-sandbox-neu", {})}}
	some msg in compared({"lz_yaml": {"products-sandbox-neu": decommissioned("products-sandbox-neu", "2020-01-01", {"state": "cancelled", "hold_days": 1})}}, main)
	contains(msg, "state cancelled follows decommissioned on main")
}

test_experiment_cancel_from_active_with_hold_days_0_is_denied if {
	main := {"lz_yaml": {"exp-aks": lz("exp-aks", {})}}
	some msg in compared({"lz_yaml": {"exp-aks": decommissioned("exp-aks", "2020-01-01", {"state": "cancelled", "hold_days": 0})}}, main)
	contains(msg, "state cancelled follows decommissioned on main")
}

test_new_file_cancelled_is_denied if {
	some msg in compared({"lz_yaml": {"exp-aks": decommissioned("exp-aks", "2020-01-01", {"state": "cancelled"})}}, {})
	contains(msg, "state cancelled follows decommissioned on main")
}

test_back_to_active_during_hold_passes if {
	main := {"lz_yaml": {"products-sandbox-neu": decommissioned("products-sandbox-neu", "2200-01-01", {})}}
	count(compared({"lz_yaml": {"products-sandbox-neu": lz("products-sandbox-neu", {})}}, main)) == 0
}

test_back_to_active_after_hold_is_denied if {
	main := {"lz_yaml": {"products-sandbox-neu": decommissioned("products-sandbox-neu", "2020-01-01", {})}}
	some msg in compared({"lz_yaml": {"products-sandbox-neu": lz("products-sandbox-neu", {})}}, main)
	contains(msg, "the hold ended on 2020-01-02")
}

test_cancelled_stays_cancelled if {
	main := {"lz_yaml": {"exp-aks": decommissioned("exp-aks", "2020-01-01", {"state": "cancelled"})}}
	some msg in compared({"lz_yaml": {"exp-aks": decommissioned("exp-aks", "2020-01-01", {})}}, main)
	contains(msg, "it was cancelled on main and stays cancelled")
}

test_redirect_in_the_domain_is_allowed if {
	count(denied(good)) == 0
}

test_redirect_with_an_unknown_field_is_denied if {
	d := [{"name": "trislab.com", "tenant": "trislab", "redirects": [{"from": "www.trislab.com", "to": "trislab.com", "code": 302}]}]
	denies(with_list("domains", d), "must be { from, to }")
}

test_redirect_outside_the_domain_is_denied if {
	d := [{"name": "trislab.com", "tenant": "trislab", "redirects": [{"from": "www.trislab.com", "to": "construction.com"}]}]
	denies(with_list("domains", array.concat(d, [{"name": "construction.com", "tenant": "trislab"}])), "is not trislab.com or one label below it")
}

test_redirect_to_itself_is_denied if {
	d := [{"name": "trislab.com", "tenant": "trislab", "redirects": [{"from": "www.trislab.com", "to": "www.trislab.com"}]}]
	denies(with_list("domains", d), "goes to itself")
}

test_redirect_source_of_a_stamp_is_denied if {
	d := [{"name": "trislab.com", "tenant": "trislab", "redirects": [{"from": "prod-corporate-site.trislab.com", "to": "trislab.com"}]}]
	denies(with_list("domains", d), "is also a hostname of a stamp")
}

test_repeated_redirect_source_is_denied if {
	d := [{"name": "trislab.com", "tenant": "trislab", "redirects": [{"from": "www.trislab.com", "to": "trislab.com"}, {"from": "www.trislab.com", "to": "trislab.com"}]}]
	denies(with_list("domains", d), "is used more than once")
}

test_more_than_ten_redirects_is_denied if {
	rs := [{"from": sprintf("a%d.trislab.com", [i]), "to": "trislab.com"} | some i in numbers.range(1, 11)]
	d := [{"name": "trislab.com", "tenant": "trislab", "redirects": rs}]
	denies(with_list("domains", d), "more than 10 redirects")
}

group_change(name, actions) := {"resource_changes": [{
	"address": "azuread_group.this[\"x\"]",
	"mode": "managed",
	"type": "azuread_group",
	"change": {"actions": actions, "before": {"display_name": name}, "after": null},
}]}

# Only this rule's messages: a bare lz.yaml trips the other landing zone rules.
group_denied(name, actions, state) := {msg |
	some msg in data.catalog.deny with input as group_change(name, actions) with data.pr as {"lz_yaml": {"products-prod-neu": lz("products-prod-neu", {"state": state})}}
	contains(msg, "is a data access group")
}

test_data_group_of_an_active_landing_zone_is_kept if {
	some msg in group_denied("grp-data-products-prod-neu-readers", ["delete"], "active")
	contains(msg, "stays until the landing zone is cancelled")
	some msg2 in group_denied("grp-data-products-prod-neu-admins", ["delete", "create"], "decommissioned")
	contains(msg2, "decommissioned")
}

test_data_group_of_a_cancelled_landing_zone_can_go if {
	count(group_denied("grp-data-products-prod-neu-readers", ["delete"], "cancelled")) == 0
}

test_data_group_create_and_other_groups_pass if {
	count(group_denied("grp-data-products-prod-neu-readers", ["create"], "active")) == 0
	count(group_denied("grp-data-cust-oc-prod-neu-admins", ["delete"], "active")) == 0
	count(group_denied("grp-devops", ["delete"], "active")) == 0
}

# ---- products.yaml, environments ----

# A product with Cloudflare Pages environments: no code, and no stamp deploys it.
site := {
	"slug": "hunting", "repo": "trislab-website-hunting", "template": "tl-template-website",
	"maintainers": ["octo-anna"], "state": "active", "domain": "trislab.com",
	"environments": [
		{"name": "dev", "hostname": "dev-hunting.trislab.com"},
		{"name": "staging", "hostname": "staging-hunting.trislab.com"},
		{"name": "production", "hostname": "prod-hunting.trislab.com", "access": "public"},
	],
}

with_site(extra) := trislab_with([corporate_site, construction_product, object.union(site, extra)])

with_site_environments(environments) := with_site({"environments": environments})

with_site_hostname(h) := with_site_environments([{"name": "dev", "hostname": h}])

test_good_site_passes if {
	count(denied(with_site({}))) == 0
}

test_a_site_may_have_one_environment if {
	count(denied(with_site_environments([{"name": "dev", "hostname": "dev-hunting.trislab.com"}]))) == 0
}

test_site_schema if {
	denies(with_site({"branch": "main"}), "has the unknown field branch")
	denies(with_site({"environments": "dev"}), "environments is dev, which is not allowed")
}

test_site_environments if {
	bad := [
		{"name": "prod", "hostname": "prod-hunting.trislab.com"},
		{"name": "dev", "hostname": "Dev-hunting.trislab.com"},
		{"name": "dev", "hostname": "dev-hunting.trislab.com", "access": "open"},
		{"name": "dev", "hostname": "dev-hunting.trislab.com", "app": "web"},
	]
	every e in bad {
		denies(with_site_environments([e]), "environments[0] of the site trislab-website-hunting must be")
	}
	twice := [{"name": "dev", "hostname": "dev-hunting.trislab.com"}, {"name": "dev", "hostname": "dev2-hunting.trislab.com"}]
	denies(with_site_environments(twice), "has the environment dev more than once")
}

# Only production can be public.
test_only_production_can_be_public if {
	count(denied(with_site_environments([{"name": "production", "hostname": "prod-hunting.trislab.com", "access": "public"}]))) == 0
	count(denied(with_site_environments([{"name": "production", "hostname": "prod-hunting.trislab.com", "access": "protected"}]))) == 0
	count(denied(with_site_environments([{"name": "production", "hostname": "prod-hunting.trislab.com"}]))) == 0
	count(denied(with_site_environments([{"name": "dev", "hostname": "dev-hunting.trislab.com", "access": "protected"}]))) == 0
}

test_dev_can_never_be_public if {
	denies(with_site_environments([{"name": "dev", "hostname": "dev-hunting.trislab.com", "access": "public"}]), "environments[0] of the site trislab-website-hunting is dev, which is never public")
}

test_staging_can_never_be_public if {
	denies(with_site_environments([{"name": "staging", "hostname": "staging-hunting.trislab.com", "access": "public"}]), "environments[0] of the site trislab-website-hunting is staging, which is never public")
}

test_site_repository if {
	denies(with_site({"template": "tl-template-saas", "repo": "trislab-saas-hunting"}), "has environments, which only an active tl-template-website repository can have")
	denies(with_site({"state": "archived", "archived_on": "2026-11-01"}), "has environments, which only an active tl-template-website repository can have")
	pr := object.union(with_site({}), {"stamp_yaml": object.union(good.stamp_yaml, {"products-sandbox-neu/hunting": stamp("construction", "trislab-website-hunting")})})
	denies(pr, "so no stamp may deploy from it, but stamps/products-sandbox-neu/hunting/stamp.yaml does")
}

test_site_hostnames if {
	denies(with_site_hostname("prod-corporate-site.trislab.com"), "the hostname prod-corporate-site.trislab.com is used more than once")
	denies(with_site_hostname("dev-hunting.example.org"), "the hostname dev-hunting.example.org of the site trislab-website-hunting is not trislab.com or exactly one label below it")
	denies(with_site_hostname("dev.hunting.trislab.com"), "is not trislab.com or exactly one label below it")
	denies(with_site_hostname("dev-hunting.astra-group.example"), "is not trislab.com or exactly one label below it")
	denies(with_site_hostname("eviltrislab.com"), "is not trislab.com or exactly one label below it")
}

test_site_hostname_may_be_the_domain_itself if {
	count([msg | some msg in denied(with_site_hostname("trislab.com")); contains(msg, "label below")]) == 0
}
