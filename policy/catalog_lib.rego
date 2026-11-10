# One normalised view of the catalog for every policy package that reads it
# (catalog, naming, tags). The catalog has two shapes, and both are accepted:
#
#   old: owners.yaml (owners), repos.yaml (repos, pages) and tenants.yaml
#        (tenants = the tenants on stamps, domains[].owner)
#   new: products.yaml (tenants[].products[]) and domains.yaml
#        (domains[].tenant, stamp_tenants)
#
# Each function takes a side of the catalog (data.pr or data.main) as d and
# returns the same shapes whichever the side has, so the rules read only the
# normalised view. The new shape is used when it is present (is_new).
#
#   tenants_n(d)        [{slug, code?, state, products: [{slug, code?, repo, template,
#                       maintainers, state, archived_on?, domain?, environments?}]}]
#   owners_n(d)         [{slug, kind, code, state}], the owner codes of 07 section 9
#   repos(tenants)      [{name, tenant, product, template, maintainers, state, archived_on?}]
#   domains_n(d)        [{name, tenant, redirects?, waf_rate_limit?}]
#   stamp_tenants_n(d)  [{name, customer, stamp, hostnames?}]
#
# From the old shape, trislab is the tenant of every repository without a
# customer, each customer owner is a tenant, and a product's code and
# environments come from the owner and the pages entry of its repository. An
# old product has no domain.
package catalog_lib

# ---- Which shape ----

is_new(d) if count(tenants_of(object.get(d, "tenants", []))) > 0

is_new(d) if "stamp_tenants" in object.keys(d)

# data.<side>.tenants is the list of stamp tenants in the old shape (entries
# with a stamp) and the list of tenants in the new one (entries with products).
tenants_of(list) := [t | some t in list; is_object(t); "products" in object.keys(t)]

stamp_tenants_of(list) := [t | some t in list; is_object(t); not "products" in object.keys(t)]

# ---- Tenants ----

tenants_n(d) := tenants_of(object.get(d, "tenants", [])) if is_new(d)

tenants_n(d) := array.concat([trislab_tenant(d)], customer_tenants(d)) if not is_new(d)

trislab_tenant(d) := {"slug": "trislab", "state": "active", "products": [product_of(d, r) |
	some r in object.get(d, "repos", [])
	not r.customer
]}

customer_tenants(d) := [{"slug": o.slug, "code": o.code, "state": o.state, "products": [product_of(d, r) |
	some r in object.get(d, "repos", [])
	r.customer == o.slug
]} |
	some o in object.get(d, "owners", [])
	o.kind == "customer"
]

product_of(d, r) := object.union(
	{"slug": r.product, "repo": r.name, "template": r.template, "maintainers": r.maintainers, "state": r.state},
	object.union(pick(r, "archived_on"), object.union(code_of(d, r.product), environments_of(d, r.name))),
)

pick(x, key) := {key: x[key]} if key in object.keys(x)

pick(x, key) := {} if not key in object.keys(x)

code_of(d, slug) := {"code": codes[0]} if {
	codes := [o.code | some o in object.get(d, "owners", []); o.kind == "product"; o.slug == slug]
	count(codes) > 0
}

code_of(d, slug) := {} if {
	codes := [o.code | some o in object.get(d, "owners", []); o.kind == "product"; o.slug == slug]
	count(codes) == 0
}

environments_of(d, repo) := {"environments": envs[0]} if {
	envs := [p.environments | some p in object.get(d, "pages", []); p.repo == repo]
	count(envs) > 0
}

environments_of(d, repo) := {} if {
	envs := [p.environments | some p in object.get(d, "pages", []); p.repo == repo]
	count(envs) == 0
}

# ---- Owners ----

# The new shape: one entry per product with a code, kind product, and one per
# tenant with a code, kind customer. The tenant trislab has no code.
owners_n(d) := owners(tenants_n(d)) if is_new(d)

owners_n(d) := object.get(d, "owners", []) if not is_new(d)

owners(tenants) := array.concat(product_owners(tenants), customer_owners(tenants))

product_owners(tenants) := [{"slug": p.slug, "kind": "product", "code": p.code, "state": owner_state(p.state)} |
	some t in tenants
	is_array(t.products)
	some p in t.products
	p.code
]

customer_owners(tenants) := [{"slug": t.slug, "kind": "customer", "code": t.code, "state": t.state} |
	some t in tenants
	t.code
]

owner_state("active") := "active"

owner_state(s) := "retired" if s != "active"

# ---- Repositories ----

repos(tenants) := [r |
	some t in tenants
	is_array(t.products)
	some p in t.products
	r := object.union(
		{"name": p.repo, "tenant": t.slug, "product": p.slug, "template": p.template, "maintainers": p.maintainers, "state": p.state},
		pick(p, "archived_on"),
	)
]

# ---- Domains and the tenants on stamps ----

domains_n(d) := object.get(d, "domains", []) if is_new(d)

domains_n(d) := [object.union({"name": x.name, "tenant": x.owner}, object.union(pick(x, "redirects"), pick(x, "waf_rate_limit"))) |
	some x in object.get(d, "domains", [])
] if not is_new(d)

stamp_tenants_n(d) := object.get(d, "stamp_tenants", []) if is_new(d)

stamp_tenants_n(d) := stamp_tenants_of(object.get(d, "tenants", [])) if not is_new(d)
