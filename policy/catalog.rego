# Catalog rules (07 section 7), run on the PR's catalog/ files.
#
#   conftest test plan.json --policy <main checkout>/policy --data <catalogs> --namespace catalog
#
# The rules read only data, so they give the same result for every root,
# except the data access group rule at the end, which reads the plan. The
# PR's catalog/ comes as data.pr and main's as data.main (08 section 3).
#
# The catalog has two shapes and both are accepted (catalog_lib.rego): the old
# owners.yaml, repos.yaml and tenants.yaml, and the new products.yaml
# (tenants with products) and domains.yaml. catalog_lib.rego turns either into
# one normalised view, and every rule below reads only that view: tenants,
# owners, repos, domains and stamp_tenants. Only the schema of the raw files
# and the few rules about a raw old list (repos, pages) depend on the shape.
# A file that doesn't exist yet passes, and so do the rules that compare the
# PR with main while main has no catalog/. The comparison with main
# normalises main the same way, so old to old, old to new and new to new all
# compare the same lists and never fail falsely or skip. Each
# stamps/<lz>/<folder>/stamp.yaml comes as data.<side>.stamp_yaml["<lz>/<folder>"].
# The default hostname rows and the custom hostname rows come before the second
# stamp (10 section 13).
package catalog

import data.catalog_lib

default pr_data := {}

pr_data := data.pr

default main_data := {}

main_data := data.main

new_shape := catalog_lib.is_new(pr_data)

tenants := catalog_lib.tenants_n(pr_data)

owners := catalog_lib.owners_n(pr_data)

repos := catalog_lib.repos(tenants)

domains := catalog_lib.domains_n(pr_data)

stamp_tenants := catalog_lib.stamp_tenants_n(pr_data)

default regions := []

regions := data.pr.regions

default hubs := []

hubs := data.pr.hubs

default landing_zones := []

landing_zones := data.pr.landing_zones

default stamp_yaml := {}

stamp_yaml := data.pr.stamp_yaml

slug := `^[a-z0-9]+(-[a-z0-9]+)*$`

fqdn := `^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,63}$`

# Field rules per list: a pattern for a string, or "cidr", "array", "object", "boolean".
schemas := {
	"tenants": {"file": "products.yaml", "section": 9, "required": {"slug", "state", "products"}, "fields": {
		"slug": slug, "code": `^[a-z]{2,3}$`, "state": `^(active|retired)$`, "products": "array",
	}},
	"products": {"file": "products.yaml", "section": 11, "required": {"slug", "repo", "template", "maintainers", "state", "domain"}, "fields": {
		"slug": slug, "code": `^[a-z]{2,3}$`, "repo": slug, "template": `^tl-template-(website|webapp|saas)$`,
		"maintainers": "array", "state": `^(active|archived)$`, "archived_on": `^[0-9]{4}-[0-9]{2}-[0-9]{2}$`,
		"domain": fqdn, "environments": "array",
	}},
	"owners": {"file": "owners.yaml", "section": 9, "required": {"slug", "kind", "code", "state"}, "fields": {
		"slug": slug, "kind": `^(customer|product)$`, "code": `^[a-z]{2,3}$`, "state": `^(active|retired)$`,
	}},
	"repos": {"file": "repos.yaml", "section": 11, "required": {"name", "product", "template", "maintainers", "state"}, "fields": {
		"name": slug, "product": slug, "customer": slug, "template": `^tl-template-(website|webapp|saas)$`,
		"maintainers": "array", "state": `^(active|archived)$`, "archived_on": `^[0-9]{4}-[0-9]{2}-[0-9]{2}$`,
	}},
	"pages": {"file": "repos.yaml", "section": 11, "required": {"repo", "environments"}, "fields": {
		"repo": slug, "environments": "array",
	}},
	"old_domains": {"label": "domains", "file": "tenants.yaml", "section": 2, "required": {"name", "owner"}, "fields": {
		"name": fqdn, "owner": slug, "redirects": "array", "waf_rate_limit": "boolean",
	}},
	"old_tenants": {"label": "tenants", "file": "tenants.yaml", "section": 2, "required": {"name", "customer", "stamp"}, "fields": {
		"name": `^[a-z0-9-]{1,40}$`, "customer": slug, "stamp": `^[a-z0-9-]+/[a-z0-9-]+$`, "hostnames": "array",
	}},
	"regions": {"file": "regions.yaml", "section": 10, "required": {"name", "cloud", "code", "state"}, "fields": {
		"name": slug, "cloud": `^(azure|gcp)$`, "code": `^[a-z0-9]{2,4}$`, "state": `^(active|retired)$`,
	}},
	"domains": {"file": "domains.yaml", "section": 2, "required": {"name", "tenant"}, "fields": {
		"name": fqdn, "tenant": slug, "redirects": "array", "waf_rate_limit": "boolean",
	}},
	"stamp_tenants": {"file": "domains.yaml", "section": 2, "required": {"name", "customer", "stamp"}, "fields": {
		"name": `^[a-z0-9-]{1,40}$`, "customer": slug, "stamp": `^[a-z0-9-]+/[a-z0-9-]+$`, "hostnames": "array",
	}},
	"hubs": {"file": "ipam.yaml", "section": 5, "required": {"name", "cloud", "region", "cidr"}, "fields": {
		"name": `^(vnet|snet)-hub-[a-z0-9]{2,4}$`, "cloud": `^(azure|gcp)$`, "region": slug, "cidr": "cidr", "subnets": "object",
	}},
	"landing_zones": {"file": "ipam.yaml", "section": 5, "required": {"name", "cidr"}, "fields": {
		"name": slug, "cidr": "cidr", "stamps": "object",
	}},
}

# [tenant, product] for every product of every tenant.
product_rows := [[t, p] |
	some t in tenants
	is_object(t)
	is_array(t.products)
	some p in t.products
]

# The raw lists of the shape the PR has, checked against their schemas.
lists := object.union({"regions": regions, "hubs": hubs, "landing_zones": landing_zones}, shape_lists)

shape_lists := {
	"tenants": object.get(pr_data, "tenants", []),
	"products": [p | some [_, p] in product_rows],
	"domains": object.get(pr_data, "domains", []),
	"stamp_tenants": object.get(pr_data, "stamp_tenants", []),
} if new_shape

shape_lists := {
	"owners": object.get(pr_data, "owners", []),
	"repos": object.get(pr_data, "repos", []),
	"pages": object.get(pr_data, "pages", []),
	"old_domains": object.get(pr_data, "domains", []),
	"old_tenants": object.get(pr_data, "tenants", []),
} if not new_shape

where(list) := sprintf("catalog/%s", [schemas[list].file])

# The name of a list in a message.
label_of(list) := object.get(schemas[list], "label", list)

product_slugs := {o.slug | some o in owners; o.kind == "product"}

customer_slugs := {o.slug | some o in owners; o.kind == "customer"}

# Reserved tokens that are not region codes (03 section 3).
reserved := {
	"root", "platform", "landingzones", "lz", "products", "cust", "prdt", "shr",
	"prod", "sandbox", "sb", "dev", "test", "uat", "perf", "demo", "staging",
	"experiment", "exp", "global", "standard", "regulated", "experiments", "decommissioned",
}

tenant_slugs := {t.slug | some t in tenants; is_object(t)}

# ---- Schema (07 sections 2, 5, 9, 10 and 11) ----

deny contains msg if {
	some list, entries in lists
	not is_array(entries)
	msg := sprintf("%s: %s must be a list (07 section %d)", [where(list), label_of(list), schemas[list].section])
}

deny contains msg if {
	some list, entries in lists
	some i, entry in entries
	not is_object(entry)
	msg := sprintf("%s: %s[%d] must be a map (07 section %d)", [where(list), label_of(list), i, schemas[list].section])
}

deny contains msg if {
	some list, entries in lists
	some i, entry in entries
	is_object(entry)
	some field in schemas[list].required
	not field in object.keys(entry)
	msg := sprintf("%s: %s[%d] has no %s (07 section %d)", [where(list), label_of(list), i, field, schemas[list].section])
}

deny contains msg if {
	some list, entries in lists
	some i, entry in entries
	is_object(entry)
	some field, _ in entry
	not schemas[list].fields[field]
	msg := sprintf("%s: %s[%d] has the unknown field %s (07 section %d)", [where(list), label_of(list), i, field, schemas[list].section])
}

deny contains msg if {
	some list, entries in lists
	some i, entry in entries
	is_object(entry)
	some field, value in entry
	rule := schemas[list].fields[field]
	not valid(rule, value)
	msg := sprintf("%s: %s[%d].%s is %v, which is not allowed (07 section %d)", [where(list), label_of(list), i, field, value, schemas[list].section])
}

valid("array", value) if is_array(value)

valid("object", value) if is_object(value)

valid("cidr", value) if cidr(value)

valid("boolean", value) if is_boolean(value)

valid(rule, value) if {
	not rule in {"array", "object", "cidr", "boolean"}
	is_string(value)
	regex.match(rule, value)
}

# An IPv4 range with no host bits set.
cidr(value) if {
	is_string(value)
	regex.match(`^[0-9.]+/[0-9]{1,2}$`, value)
	net.cidr_is_valid(value)
	net.cidr_merge([value]) == {value}
}

prefix(c) := to_number(split(c, "/")[1])

duplicates(list, key) := {v |
	some entry in lists[list]
	v := entry[key]
	count([e | some e in lists[list]; e[key] == v]) > 1
}

deny contains msg if {
	some [list, key] in [["owners", "slug"], ["owners", "code"], ["repos", "name"], ["pages", "repo"], ["tenants", "slug"], ["products", "repo"], ["regions", "code"], ["domains", "name"], ["old_domains", "name"], ["hubs", "name"], ["landing_zones", "name"]]
	some v in duplicates(list, key)
	msg := sprintf("%s: the %s %v is used more than once (07 section %d)", [where(list), key, v, schemas[list].section])
}

# ---- Owner and region codes (07 sections 9 and 10, 03 section 3) ----

deny contains msg if {
	some o in owners
	o.code in reserved
	msg := sprintf("catalog/products.yaml: the code %v of %v is a reserved token (03 section 3)", [o.code, o.slug])
}

deny contains msg if {
	some o in owners
	some r in regions
	o.code == r.code
	msg := sprintf("catalog/products.yaml: the code %v of %v is also the code of the region %v (03 section 3)", [o.code, o.slug, r.name])
}

deny contains msg if {
	some r in regions
	r.code in reserved
	msg := sprintf("catalog/regions.yaml: the code %v of %v is a reserved token (03 section 3)", [r.code, r.name])
}

deny contains msg if {
	some r in regions
	count([x | some x in regions; x.cloud == r.cloud; x.name == r.name]) > 1
	msg := sprintf("catalog/regions.yaml: the %v region %v is listed more than once (07 section 10)", [r.cloud, r.name])
}

# ---- products.yaml: tenants and products (07 sections 9 and 11) ----

# trislab is the platform's own owner, so it has no code. Every other tenant
# keeps a required code (07 section 9).
deny contains msg if {
	some t in tenants
	is_object(t)
	t.slug != "trislab"
	not t.code
	msg := sprintf("catalog/products.yaml: the tenant %v has no code, which every tenant but trislab needs, 2 or 3 letters (07 section 9)", [t.slug])
}

deny contains msg if {
	some t in tenants
	is_object(t)
	t.slug == "trislab"
	t.code
	msg := sprintf("catalog/products.yaml: the tenant trislab is the platform's own owner and has no code, not %v (07 section 9)", [t.code])
}

# A product's slug is unique within its tenant, not across tenants. The old
# shape lists repositories, and several of them may name one product.
deny contains msg if {
	new_shape
	some [t, p] in product_rows
	count([q | some [u, q] in product_rows; u.slug == t.slug; q.slug == p.slug]) > 1
	msg := sprintf("catalog/products.yaml: the tenant %v has the product %v more than once (07 section 11)", [t.slug, p.slug])
}

# The code of a product is only needed when a stamp deploys it.
deny contains msg if {
	some [t, p] in product_rows
	not p.code
	some stamp, s in stamp_yaml
	some a in s.apps
	a.repo == p.repo
	msg := sprintf("catalog/products.yaml: the product %v of %v has no code, which a product needs once a stamp deploys from its repository, but stamps/%s/stamp.yaml does (07 section 9)", [p.slug, t.slug, stamp])
}

# An owner slug is looked up by the stamps (a product's, or a client tenant's),
# and an owner code is never shared.
deny contains msg if {
	some key in ["slug", "code"]
	some v in {o[key] | some o in owners; count([x | some x in owners; x[key] == o[key]]) > 1}
	msg := sprintf("catalog/products.yaml: the %s %v is used by more than one product or client tenant with a code (07 section 9)", [key, v])
}

# <tenant>-<appType>-<product>.
deny contains msg if {
	some [t, p] in product_rows
	is_string(p.template)
	want := sprintf("%v-%v-%v", [t.slug, trim_prefix(p.template, "tl-template-"), p.slug])
	p.repo != want
	msg := sprintf("catalog/products.yaml: %v must be named %v, from its tenant, its template and its product (07 section 11)", [p.repo, want])
}

deny contains msg if {
	some [_, p] in product_rows
	is_array(p.maintainers)
	not valid_maintainers(p.maintainers)
	msg := sprintf("catalog/products.yaml: %v needs at least one maintainer, each a GitHub user name (07 section 11)", [p.repo])
}

valid_maintainers(list) if {
	count(list) > 0
	every m in list {
		is_string(m)
		regex.match(`^[A-Za-z0-9](-?[A-Za-z0-9]){0,38}$`, m)
	}
}

deny contains msg if {
	some [_, p] in product_rows
	p.state == "archived"
	not p.archived_on
	msg := sprintf("catalog/products.yaml: %v is archived and has no archived_on (07 section 11)", [p.repo])
}

# A product has one domain, which is in domains and belongs to its tenant.
deny contains msg if {
	some [t, p] in product_rows
	is_string(p.domain)
	not p.domain in {d.name | some d in domains; is_string(d.name)}
	msg := sprintf("catalog/products.yaml: the product %v of %v names the domain %v, which is not in catalog/domains.yaml (07 section 3.2)", [p.slug, t.slug, p.domain])
}

deny contains msg if {
	some [t, p] in product_rows
	some d in domains
	d.name == p.domain
	d.tenant != t.slug
	msg := sprintf("catalog/products.yaml: the product %v of %v is on the domain %v, which belongs to the tenant %v (07 section 3.2)", [p.slug, t.slug, d.name, d.tenant])
}

# ---- Old shape: owners.yaml, repos.yaml and pages (07 section 11) ----

# What only the raw old lists can say. The rules about names, maintainers,
# archiving, environments and hostnames below read the normalised view.

deny contains msg if {
	some r in object.get(pr_data, "repos", [])
	not r.product in product_slugs
	msg := sprintf("catalog/repos.yaml: %v names the product %v, which is not a product in catalog/owners.yaml (07 section 11)", [r.name, r.product])
}

deny contains msg if {
	some r in object.get(pr_data, "repos", [])
	r.customer
	not r.customer in customer_slugs
	msg := sprintf("catalog/repos.yaml: %v names the customer %v, which is not a customer in catalog/owners.yaml (07 section 11)", [r.name, r.customer])
}

deny contains msg if {
	some p in object.get(pr_data, "pages", [])
	not p.repo in {r.name | some r in object.get(pr_data, "repos", []); r.state == "active"; r.template == "tl-template-website"}
	msg := sprintf("catalog/repos.yaml: the site %v is not an active tl-template-website repository in repos (07 section 11)", [p.repo])
}

# ---- Environments: sites on Cloudflare Pages (07 section 11) ----

# [repo, i, environment] for every environment of a site.
pages_environments contains [p.repo, i, e] if {
	some [_, p] in product_rows
	is_array(p.environments)
	some i, e in p.environments
}

valid_pages_environment(e) if {
	is_object(e)
	object.keys(e) - {"access"} == {"name", "hostname"}
	e.name in {"dev", "staging", "production"}
	is_string(e.hostname)
	regex.match(fqdn, e.hostname)
	valid_access(e)
}

pages_fqdns := [e.hostname | some [_, _, e] in pages_environments; valid_pages_environment(e)]

deny contains msg if {
	some [repo, i, e] in pages_environments
	not valid_pages_environment(e)
	msg := sprintf("catalog/products.yaml: environments[%d] of the site %v must be { name, hostname } with the name dev, staging or production and a lowercase FQDN, and an optional access: public or protected (07 section 11)", [i, repo])
}

# Only production can be public. dev and staging are always behind Cloudflare Access.
deny contains msg if {
	some [repo, i, e] in pages_environments
	is_object(e)
	e.access == "public"
	e.name != "production"
	msg := sprintf("catalog/products.yaml: environments[%d] of the site %v is %v, which is never public: only production can have access: public (07 section 3.3)", [i, repo, e.name])
}

deny contains msg if {
	some [_, p] in product_rows
	is_array(p.environments)
	some n in {e.name | some e in p.environments; is_object(e)}
	count([e | some e in p.environments; is_object(e); e.name == n]) > 1
	msg := sprintf("catalog/products.yaml: the site %v has the environment %v more than once (07 section 11)", [p.repo, n])
}

deny contains msg if {
	some [_, p] in product_rows
	is_array(p.environments)
	count(p.environments) > 0
	not [p.template, p.state] == ["tl-template-website", "active"]
	msg := sprintf("catalog/products.yaml: %v has environments, which only an active tl-template-website repository can have (07 section 11)", [p.repo])
}

# A repository deploys either to Cloudflare Pages or to stamps.
deny contains msg if {
	some [_, p] in product_rows
	is_array(p.environments)
	count(p.environments) > 0
	some stamp, s in stamp_yaml
	some a in s.apps
	a.repo == p.repo
	msg := sprintf("catalog/products.yaml: the site %v is on Cloudflare Pages, so no stamp may deploy from it, but stamps/%s/stamp.yaml does (07 section 11)", [p.repo, stamp])
}

# A product without a domain (the old shape has none) is checked against the
# domains: its hostname is in one, at most one label below it, and the domain
# is its tenant's or trislab's.
deny contains msg if {
	some [_, p] in product_rows
	not p.domain
	is_array(p.environments)
	some e in p.environments
	valid_pages_environment(e)
	not domain_of(e.hostname)
	msg := sprintf("catalog/repos.yaml: the hostname %v of the site %v is in no domain of domains in catalog/tenants.yaml (07 section 3.2)", [e.hostname, p.repo])
}

deny contains msg if {
	some [_, p] in product_rows
	not p.domain
	is_array(p.environments)
	some e in p.environments
	valid_pages_environment(e)
	d := domain_of(e.hostname)
	e.hostname != d
	contains(trim_suffix(e.hostname, concat("", [".", d])), ".")
	msg := sprintf("catalog/repos.yaml: the hostname %v of the site %v is more than one label below %v (07 section 3)", [e.hostname, p.repo, d])
}

deny contains msg if {
	some [t, p] in product_rows
	not p.domain
	is_array(p.environments)
	some e in p.environments
	valid_pages_environment(e)
	d := domain_of(e.hostname)
	owner := {x.tenant | some x in domains; x.name == d}
	count(owner & {t.slug, "trislab"}) == 0
	msg := sprintf("catalog/repos.yaml: the hostname %v of the site %v is in %v, which belongs to another customer (07 section 3.2)", [e.hostname, p.repo, d])
}

# Every hostname is the product's domain, or exactly one label below it.
deny contains msg if {
	some [_, p] in product_rows
	is_string(p.domain)
	is_array(p.environments)
	some e in p.environments
	valid_pages_environment(e)
	not redirect_name_in(e.hostname, p.domain)
	msg := sprintf("catalog/products.yaml: the hostname %v of the site %v is not %v or exactly one label below it (07 section 3)", [e.hostname, p.repo, p.domain])
}

# ---- domains.yaml: domains and the tenants on stamps (07 sections 2 and 3) ----

deny contains msg if {
	some d in domains
	not d.tenant in tenant_slugs
	msg := sprintf("catalog/domains.yaml: the domain %v has the tenant %v, which is not a tenant in catalog/products.yaml (07 section 2.1)", [d.name, d.tenant])
}

deny contains msg if {
	some t in stamp_tenants
	not t.customer in tenant_slugs
	msg := sprintf("catalog/domains.yaml: the tenant %v on %v has the customer %v, which is not a tenant in catalog/products.yaml (07 section 2.2)", [t.name, t.stamp, t.customer])
}

deny contains msg if {
	some t in stamp_tenants
	count([x | some x in stamp_tenants; x.name == t.name; x.stamp == t.stamp]) > 1
	msg := sprintf("catalog/domains.yaml: the tenant %v is on %v more than once (07 section 2.2)", [t.name, t.stamp])
}

# A tenant on a stamp in a customer landing zone belongs to that customer.
deny contains msg if {
	some t in stamp_tenants
	is_string(t.stamp)
	code := customer_code(t.stamp)
	not t.customer in {o.slug | some o in owners; o.kind == "customer"; o.code == code}
	msg := sprintf("catalog/domains.yaml: the tenant %v on %v must have the customer whose code is %v (07 section 7)", [t.name, t.stamp, code])
}

customer_code(stamp) := m[0][1] if {
	m := regex.find_all_string_submatch_n(`^cust-([a-z]{2,3})-`, stamp, 1)
	count(m) == 1
}

# [tenant, stamp, customer, i, hostname] for every hostname.
hostnames contains [t.name, t.stamp, t.customer, i, h] if {
	some t in stamp_tenants
	is_array(t.hostnames)
	some i, h in t.hostnames
}

deny contains msg if {
	some [name, stamp, _, i, h] in hostnames
	not valid_hostname(h)
	msg := sprintf("catalog/domains.yaml: hostnames[%d] of %v on %v must be { fqdn, app } with a lowercase FQDN and an app name, and an optional access: public or protected (07 section 2.2)", [i, name, stamp])
}

valid_hostname(h) if {
	is_object(h)
	object.keys(h) - {"access"} == {"fqdn", "app"}
	is_string(h.fqdn)
	regex.match(fqdn, h.fqdn)
	is_string(h.app)
	regex.match(slug, h.app)
	valid_access(h)
}

valid_access(h) if not "access" in object.keys(h)

valid_access(h) if h.access in {"public", "protected"}

# A sandbox hostname is always behind Cloudflare Access, so it can't be public.
deny contains msg if {
	some [name, stamp, _, i, h] in hostnames
	contains(split(stamp, "/")[0], "-sandbox-")
	h.access == "public"
	msg := sprintf("catalog/domains.yaml: hostnames[%d] of %v on %v is in a sandbox landing zone, which is always protected: remove access: public (07 section 3.3)", [i, name, stamp])
}

all_fqdns := array.concat([h.fqdn | some [_, _, _, _, h] in hostnames], pages_fqdns)

deny contains msg if {
	some f in {f | some f in all_fqdns}
	count([x | some x in all_fqdns; x == f]) > 1
	msg := sprintf("catalog/domains.yaml: the hostname %v is used more than once (07 section 2.2)", [f])
}

deny contains msg if {
	some [name, stamp, _, _, h] in hostnames
	is_string(h.fqdn)
	not domain_of(h.fqdn)
	msg := sprintf("catalog/domains.yaml: the hostname %v of %v on %v is in no domain of domains (07 section 3.2)", [h.fqdn, name, stamp])
}

deny contains msg if {
	some [name, stamp, customer, _, h] in hostnames
	d := domain_of(h.fqdn)
	owner := {x.tenant | some x in domains; x.name == d}
	count(owner & {customer, "trislab"}) == 0
	msg := sprintf("catalog/domains.yaml: the hostname %v of %v on %v is in %v, which belongs to another customer (07 section 3.2)", [h.fqdn, name, stamp, d])
}

# ---- domains[].redirects (07 section 2.1.1) ----

# [domain, i, redirect] for every redirect.
redirects contains [d.name, i, r] if {
	some d in domains
	is_array(d.redirects)
	some i, r in d.redirects
}

valid_redirect(r) if {
	is_object(r)
	object.keys(r) == {"from", "to"}
	is_string(r.from)
	regex.match(fqdn, r.from)
	is_string(r.to)
	regex.match(fqdn, r.to)
}

deny contains msg if {
	some [name, i, r] in redirects
	not valid_redirect(r)
	msg := sprintf("catalog/domains.yaml: redirects[%d] of %v must be { from, to } with lowercase FQDNs (07 section 2.1.1)", [i, name])
}

# Both names are the domain or one label below it.
deny contains msg if {
	some [name, _, r] in redirects
	valid_redirect(r)
	some h in [r.from, r.to]
	not redirect_name_in(h, name)
	msg := sprintf("catalog/domains.yaml: the redirect name %v is not %v or one label below it (07 section 2.1.1)", [h, name])
}

redirect_name_in(h, d) if h == d

redirect_name_in(h, d) if {
	endswith(h, concat("", [".", d]))
	not contains(trim_suffix(h, concat("", [".", d])), ".")
}

deny contains msg if {
	some [name, _, r] in redirects
	valid_redirect(r)
	r.from == r.to
	msg := sprintf("catalog/domains.yaml: the redirect of %v in %v goes to itself (07 section 2.1.1)", [r.from, name])
}

all_redirect_sources := [r.from | some [_, _, r] in redirects; valid_redirect(r)]

deny contains msg if {
	some f in {f | some f in all_redirect_sources}
	count([x | some x in all_redirect_sources; x == f]) > 1
	msg := sprintf("catalog/domains.yaml: the redirect source %v is used more than once (07 section 2.1.1)", [f])
}

deny contains msg if {
	some f in all_redirect_sources
	f in all_fqdns
	msg := sprintf("catalog/domains.yaml: the redirect source %v is also a hostname of a stamp (07 section 2.1.1)", [f])
}

# The Free plan allows 10 Single Redirects rules per zone.
deny contains msg if {
	some d in domains
	is_array(d.redirects)
	count(d.redirects) > 10
	msg := sprintf("catalog/domains.yaml: the domain %v has more than 10 redirects, the Free plan's limit per zone (07 section 2.1.1)", [d.name])
}

# At most one label below its domain, so the universal certificate covers it.
deny contains msg if {
	some [name, stamp, _, _, h] in hostnames
	d := domain_of(h.fqdn)
	h.fqdn != d
	contains(trim_suffix(h.fqdn, concat("", [".", d])), ".")
	msg := sprintf("catalog/domains.yaml: the hostname %v of %v on %v is more than one label below %v (07 section 3)", [h.fqdn, name, stamp, d])
}

# The longest domain in domains that the hostname is in.
domain_of(f) := d if {
	names := [x.name | some x in domains; is_string(x.name); in_domain(f, x.name)]
	count(names) > 0
	longest := max([count(n) | some n in names])
	some d in names
	count(d) == longest
}

in_domain(f, d) if f == d

in_domain(f, d) if endswith(f, concat("", [".", d]))

# ---- stamp.yaml (07 section 7) ----

deny contains msg if {
	some t in stamp_tenants
	is_string(t.stamp)
	not stamp_yaml[t.stamp]
	msg := sprintf("catalog/domains.yaml: the tenant %v is on %v, which has no stamps/%v/stamp.yaml (07 section 7)", [t.name, t.stamp, t.stamp])
}

deny contains msg if {
	some [name, stamp, _, i, h] in hostnames
	s := stamp_yaml[stamp]
	is_string(h.app)
	not external_app(s, h.app)
	msg := sprintf("catalog/domains.yaml: hostnames[%d] of %v on %v names the app %v, which is not an app of the stamp with ingress: external (07 section 7)", [i, name, stamp, h.app])
}

external_app(s, app) if {
	some a in s.apps
	a.name == app
	a.ingress == "external"
}

deny contains msg if {
	some stamp, s in stamp_yaml
	some a in s.apps
	not a.repo in {r.name | some r in repos; r.state == "active"}
	msg := sprintf("stamps/%s/stamp.yaml: the app %v deploys from %v, which is not an active repository of a product in the catalog (07 section 7)", [stamp, a.name, a.repo])
}

# ---- ipam.yaml (07 sections 5 and 6) ----

ipam if data.pr.pools

ipam if data.pr.hubs

ipam if data.pr.landing_zones

default pools_value := null

pools_value := data.pr.pools

pools := {"hubs": "10.0.0.0/12", "prod": "10.16.0.0/12", "sandbox": "10.32.0.0/12"}

hub_halves := {"azure": "10.0.0.0/13", "gcp": "10.8.0.0/13"}

deny contains msg if {
	ipam
	pools_value != pools
	msg := sprintf("catalog/ipam.yaml: pools must be %v; changing a pool is a new ADR (07 section 5)", [pools])
}

deny contains msg if {
	some h in hubs
	cidr(h.cidr)
	prefix(h.cidr) != 20
	msg := sprintf("catalog/ipam.yaml: the hub %v must be a /20, not %v (07 section 5)", [h.name, h.cidr])
}

deny contains msg if {
	some h in hubs
	cidr(h.cidr)
	half := hub_halves[h.cloud]
	not net.cidr_contains(half, h.cidr)
	msg := sprintf("catalog/ipam.yaml: the %v hub %v must be inside %v (07 section 5)", [h.cloud, h.name, half])
}

deny contains msg if {
	some h in hubs
	is_string(h.name)
	h.cloud == "azure"
	not startswith(h.name, "vnet-hub-")
	msg := sprintf("catalog/ipam.yaml: the azure hub %v must be named vnet-hub-<code> (07 section 5)", [h.name])
}

deny contains msg if {
	some h in hubs
	is_string(h.name)
	h.cloud == "gcp"
	not startswith(h.name, "snet-hub-")
	msg := sprintf("catalog/ipam.yaml: the gcp hub %v must be named snet-hub-<code> (07 section 5)", [h.name])
}

deny contains msg if {
	some h in hubs
	not h.region in {r.name | some r in regions; r.cloud == h.cloud; r.state == "active"}
	msg := sprintf("catalog/ipam.yaml: the hub %v is in %v, which is not an active %v region in catalog/regions.yaml (07 section 7)", [h.name, h.region, h.cloud])
}

deny contains msg if {
	some h in hubs
	is_string(h.name)
	some r in regions
	r.cloud == h.cloud
	r.name == h.region
	not endswith(h.name, concat("", ["-hub-", r.code]))
	msg := sprintf("catalog/ipam.yaml: the hub %v is in %v, so its name must end in -hub-%v (07 section 5)", [h.name, h.region, r.code])
}

deny contains msg if {
	some h in hubs
	cidr(h.cidr)
	is_object(h.subnets)
	some name, c in h.subnets
	cidr(c)
	not net.cidr_contains(h.cidr, c)
	msg := sprintf("catalog/ipam.yaml: the subnet %v (%v) is outside the hub %v (07 section 5)", [name, c, h.name])
}

deny contains msg if {
	some h in hubs
	is_object(h.subnets)
	some name, c in h.subnets
	not cidr(c)
	msg := sprintf("catalog/ipam.yaml: the subnet %v of %v has the range %v, which is not an IPv4 CIDR (07 section 5)", [name, h.name, c])
}

deny contains msg if {
	some h in hubs
	cidr(h.cidr)
	gateway := h.subnets.GatewaySubnet
	not at_start(gateway, h.cidr)
	msg := sprintf("catalog/ipam.yaml: the GatewaySubnet of %v must be a /27 at the start of %v (07 section 5)", [h.name, h.cidr])
}

at_start(c, container) if {
	cidr(c)
	prefix(c) == 27
	split(c, "/")[0] == split(container, "/")[0]
}

lz_name := `^(?:products|cust-[a-z]{2,3}|prdt-[a-z]{2,3})-(prod|sandbox)-[a-z0-9]{2,4}(?:-[0-9]{2})?$`

deny contains msg if {
	some lz in landing_zones
	is_string(lz.name)
	not regex.match(lz_name, lz.name)
	msg := sprintf("catalog/ipam.yaml: %v is not a landing zone name (03 section 7.3)", [lz.name])
}

deny contains msg if {
	some lz in landing_zones
	cidr(lz.cidr)
	prefix(lz.cidr) != 20
	msg := sprintf("catalog/ipam.yaml: the landing zone %v must be a /20, not %v (07 section 5)", [lz.name, lz.cidr])
}

deny contains msg if {
	some lz in landing_zones
	cidr(lz.cidr)
	m := regex.find_all_string_submatch_n(lz_name, lz.name, 1)
	count(m) == 1
	envtype := m[0][1]
	not net.cidr_contains(pools[envtype], lz.cidr)
	msg := sprintf("catalog/ipam.yaml: the %v landing zone %v must be inside the %v pool %v (07 section 6.1)", [envtype, lz.name, envtype, pools[envtype]])
}

deny contains msg if {
	some lz in landing_zones
	cidr(lz.cidr)
	is_object(lz.stamps)
	some stamp, c in lz.stamps
	cidr(c)
	not net.cidr_contains(lz.cidr, c)
	msg := sprintf("catalog/ipam.yaml: the stamp %v (%v) is outside the landing zone %v (07 section 5)", [stamp, c, lz.name])
}

deny contains msg if {
	some lz in landing_zones
	is_object(lz.stamps)
	some stamp, c in lz.stamps
	not cidr(c)
	msg := sprintf("catalog/ipam.yaml: the stamp %v of %v has the range %v, which is not an IPv4 CIDR (07 section 5)", [stamp, lz.name, c])
}

# A managed stamp runs on Azure's network and takes no range (ADR 0058).
deny contains msg if {
	some key, s in stamp_yaml
	s.network.mode == "managed"
	parts := split(key, "/")
	some lz in landing_zones
	lz.name == parts[0]
	is_object(lz.stamps)
	lz.stamps[parts[1]]
	msg := sprintf("catalog/ipam.yaml: the stamp %v has network.mode managed, so it takes no range: remove %v under %v (07 section 6.3, ADR 0058)", [key, parts[1], parts[0]])
}

# No two ranges overlap, except a stamp inside its landing zone and a subnet inside its hub.
deny contains msg if {
	some groups in range_groups
	some i, a in groups
	some j, b in groups
	i < j
	net.cidr_intersects(a[1], b[1])
	msg := sprintf("catalog/ipam.yaml: %v (%v) overlaps %v (%v) (07 section 7)", [a[0], a[1], b[0], b[1]])
}

range_groups contains array.concat(
	[[h.name, h.cidr] | some h in hubs; cidr(h.cidr)],
	[[lz.name, lz.cidr] | some lz in landing_zones; cidr(lz.cidr)],
)

range_groups contains [[name, c] | some name, c in h.subnets; cidr(c)] if {
	some h in hubs
	is_object(h.subnets)
}

range_groups contains [[name, c] | some name, c in lz.stamps; cidr(c)] if {
	some lz in landing_zones
	is_object(lz.stamps)
}

# ---- Compared with main (07 section 7) ----

# Main's lists, normalised like the PR's (catalog_lib.rego), so a PR is compared
# the same way whichever shape main and the PR have: old to old, old to new
# (the PR that moves the catalog to products.yaml and domains.yaml), and new to
# new. The comparison never skips, and it passes while the PR keeps every
# owner, repository and code of main.

main_tenants := catalog_lib.tenants_n(main_data)

main_owners := catalog_lib.owners_n(main_data)

main_repos := catalog_lib.repos(main_tenants)

main_stamp_tenants := catalog_lib.stamp_tenants_n(main_data)

# A tenant is retired with state: retired, never deleted.
deny contains msg if {
	catalog_lib.is_new(main_data)
	some m in main_tenants
	not m.slug in tenant_slugs
	msg := sprintf("catalog/products.yaml: the tenant %v was removed or renamed; a tenant is retired with state: retired, never deleted (07 section 7)", [m.slug])
}

# A product is archived with state: archived, never deleted.
deny contains msg if {
	catalog_lib.is_new(main_data)
	some t in main_tenants
	some p in t.products
	not [t.slug, p.slug] in {[u.slug, q.slug] | some [u, q] in product_rows}
	msg := sprintf("catalog/products.yaml: the product %v of %v was removed or renamed; a product is archived with state: archived, never deleted (07 section 11)", [p.slug, t.slug])
}

deny contains msg if {
	some m in main_owners
	not m.slug in {o.slug | some o in owners}
	not renamed(m)
	msg := sprintf("catalog/products.yaml: %v was removed or renamed; an owner is retired with state: retired, never deleted, and its slug changes only while nothing on main references it (07 section 7)", [m.slug])
}

deny contains msg if {
	some o in owners
	not o.slug in {m.slug | some m in main_owners}
	some m in main_owners
	m.code == o.code
	not m.slug in {x.slug | some x in owners}
	not renamed(m)
	msg := sprintf("catalog/products.yaml: %v takes the code %v of %v on main; a code is never reused (07 section 9)", [o.slug, o.code, m.slug])
}

# The one exception to "no slug changes": a new slug with main's code, kind and
# state, while nothing on main references the old one (07 section 7).
renamed(m) if {
	some o in owners
	not o.slug in {x.slug | some x in main_owners}
	[o.code, o.kind, o.state] == [m.code, m.kind, m.state]
	not referenced_on_main(m)
}

referenced_on_main(m) if {
	some s in object.get(main_data, "stamp_yaml", {})
	s.product == m.slug
}

referenced_on_main(m) if {
	some r in main_repos
	r.product == m.slug
}

referenced_on_main(m) if {
	some r in main_repos
	r.customer == m.slug
}

referenced_on_main(m) if {
	some r in main_repos
	r.tenant == m.slug
}

referenced_on_main(m) if {
	some t in main_stamp_tenants
	t.customer == m.slug
}

referenced_on_main(m) if {
	some d in object.get(main_data, "domains", [])
	d.owner == m.slug
}

referenced_on_main(m) if {
	some d in object.get(main_data, "domains", [])
	d.tenant == m.slug
}

referenced_on_main(m) if {
	m.kind == "customer"
	some lz, _ in data.main.lz_yaml
	startswith(lz, sprintf("cust-%v-", [m.code]))
}

deny contains msg if {
	some m in main_owners
	some o in owners
	o.slug == m.slug
	o.code != m.code
	msg := sprintf("catalog/products.yaml: the code of %v changed from %v to %v; a code never changes (07 section 9)", [m.slug, m.code, o.code])
}

deny contains msg if {
	some m in data.main.regions
	not [m.cloud, m.name] in {[r.cloud, r.name] | some r in regions}
	msg := sprintf("catalog/regions.yaml: the %v region %v was removed or renamed; a region is retired with state: retired, never deleted (07 section 10)", [m.cloud, m.name])
}

deny contains msg if {
	some m in data.main.regions
	some r in regions
	[r.cloud, r.name] == [m.cloud, m.name]
	r.code != m.code
	msg := sprintf("catalog/regions.yaml: the code of %v changed from %v to %v; a code never changes (07 section 10)", [m.name, m.code, r.code])
}

deny contains msg if {
	some m in main_repos
	not m.name in {r.name | some r in repos}
	msg := sprintf("catalog/products.yaml: the repository %v was removed or renamed; a product's repository is archived with state: archived, never deleted (07 section 11)", [m.name])
}

# ---- landing-zones/<lz>.yaml (05 section 3) ----
#
# Each file comes as data.<side>.lz_yaml["<lz>"]. The landing-zone module checks
# the rest of the file on plan; these rules need the file name, main or today.

default lz_yaml := {}

lz_yaml := data.pr.lz_yaml

default main_lz_yaml := {}

main_lz_yaml := data.main.lz_yaml

deny contains msg if {
	some lz, y in lz_yaml
	"production_data" in object.keys(y)
	not contains(lz, "-prod-")
	msg := sprintf("landing-zones/%s.yaml: production_data is set only in a prod landing zone (05 section 2)", [lz])
}

deny contains msg if {
	some lz, m in data.main.lz_yaml
	m.production_data == true
	y := lz_yaml[lz]
	not y.production_data == true
	msg := sprintf("landing-zones/%s.yaml: production_data was true on main; it never goes back to false (05 section 2)", [lz])
}

deny contains msg if {
	some lz, y in lz_yaml
	y.name != lz
	msg := sprintf("landing-zones/%s.yaml: name is %v; it must be the file name (05 section 2)", [lz, y.name])
}

# A landing zone peers with the hub of its region, so the hub is in
# catalog/ipam.yaml first (05 section 5). An experiment has no region.
deny contains msg if {
	some lz, y in lz_yaml
	is_string(y.region)
	not y.region in {h.region | some h in hubs; h.cloud == y.cloud}
	msg := sprintf("landing-zones/%s.yaml: there is no %v hub in %v in catalog/ipam.yaml; the hub is built first (05 section 5)", [lz, y.cloud, y.region])
}

# An experiment gets at most 90 days when its file is added, and is extended by
# PR to at most 180 in total, which the module checks (ADR 0051).
deny contains msg if {
	some lz, y in lz_yaml
	y.archetype == "experiment"
	not data.main.lz_yaml[lz]
	to_number(trim_suffix(y.ttl, "d")) > 90
	msg := sprintf("landing-zones/%s.yaml: a new experiment's ttl is at most 90d (ADR 0051)", [lz])
}

deny contains msg if {
	some lz, y in lz_yaml
	"decommissioned_on" in object.keys(y)
	not is_date(y.decommissioned_on)
	msg := sprintf("landing-zones/%s.yaml: decommissioned_on must be a date, YYYY-MM-DD (05 section 2)", [lz])
}

# Section 7: active, then decommissioned, then cancelled. A landing zone is
# cancelled only after its hold, and taken back to active only during it. The
# hold is counted from main's file, so a PR can't shorten it.
deny contains msg if {
	some lz, y in lz_yaml
	y.state == "cancelled"
	not object.get(main_lz_yaml, [lz, "state"], "") in {"decommissioned", "cancelled"}
	not cancelled_without_hold(lz, y)
	msg := sprintf("landing-zones/%s.yaml: state cancelled follows decommissioned on main, or active with hold_days: 0 outside an experiment (05 section 7)", [lz])
}

# Outside an experiment, hold_days: 0 takes an active landing zone straight to
# cancelled in one PR. An experiment's cancel would run in the same apply as
# its move to mg-decommissioned (05 section 7).
cancelled_without_hold(lz, y) if {
	object.get(main_lz_yaml, [lz, "state"], "") == "active"
	not startswith(lz, "exp-")
	y.hold_days == 0
	"decommissioned_on" in object.keys(y)
}

deny contains msg if {
	some lz, y in lz_yaml
	y.state == "cancelled"
	m := data.main.lz_yaml[lz]
	m.state == "decommissioned"
	time.now_ns() < hold_end(lz, m)
	msg := sprintf("landing-zones/%s.yaml: the hold ends on %s; it is cancelled after that (05 section 7)", [lz, date(hold_end(lz, m))])
}

deny contains msg if {
	some lz, y in lz_yaml
	y.state == "active"
	m := data.main.lz_yaml[lz]
	m.state == "decommissioned"
	time.now_ns() >= hold_end(lz, m)
	msg := sprintf("landing-zones/%s.yaml: the hold ended on %s, so it can't be active again (05 section 7)", [lz, date(hold_end(lz, m))])
}

deny contains msg if {
	some lz, m in data.main.lz_yaml
	m.state == "cancelled"
	y := lz_yaml[lz]
	y.state != "cancelled"
	msg := sprintf("landing-zones/%s.yaml: it was cancelled on main and stays cancelled (05 section 7)", [lz])
}

is_date(s) if {
	regex.match(`^[0-9]{4}-[0-9]{2}-[0-9]{2}$`, s)
	time.parse_ns("2006-01-02", s)
}

# 1 day, 0 for an experiment, unless the file sets hold_days (05 section 2).
hold_days(_, y) := y.hold_days

hold_days(lz, y) := 0 if {
	not y.hold_days
	startswith(lz, "exp-")
}

hold_days(lz, y) := 1 if {
	not y.hold_days
	not startswith(lz, "exp-")
}

hold_end(lz, y) := time.add_date(time.parse_ns("2006-01-02", y.decommissioned_on), 0, 0, hold_days(lz, y))

date(ns) := sprintf("%d-%02d-%02d", time.date(ns))

# A landing zone's data access groups grp-data-<lz>-readers and -admins
# (ADR 0052) stay while its lz.yaml isn't cancelled: the landing-zone module
# reads them, so deleting one fails every plan of the landing zone, and it
# loses its members and its role assignments. A replace deletes too. The rule
# reads the plan, so it guards platform/azure/identity.
deny contains msg if {
	some rc in input.resource_changes
	rc.type == "azuread_group"
	"delete" in rc.change.actions
	name := rc.change.before.display_name
	m := regex.find_all_string_submatch_n(`^grp-data-(.+)-(?:readers|admins)$`, name, 1)
	count(m) == 1
	y := lz_yaml[m[0][1]]
	y.state != "cancelled"
	msg := sprintf("%s: %s is a data access group of the landing zone %s, which is %s: it stays until the landing zone is cancelled (ADR 0052). Was a commit that removes it rebased onto main?", [rc.address, name, m[0][1], y.state])
}
