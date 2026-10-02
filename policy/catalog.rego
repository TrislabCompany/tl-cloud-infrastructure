# Catalog rules (07 section 7), run on the PR's catalog/ files.
#
#   conftest test plan.json --policy <main checkout>/policy --data <catalogs> --namespace catalog
#
# The rules read only data, so they give the same result for every root. The
# PR's catalog/ comes as data.pr and main's as data.main (08 section 3). A file
# that doesn't exist yet passes, and so do the rules that compare the PR with
# main while main has no catalog/. The rules that need a stamp's stamp.yaml (the stamp
# folder and its external apps, the default hostname, the sandbox form of a
# custom hostname, apps[].repo) come with the first stamp template.
package catalog

default owners := []

owners := data.pr.owners

default regions := []

regions := data.pr.regions

default repos := []

repos := data.pr.repos

default domains := []

domains := data.pr.domains

default tenants := []

tenants := data.pr.tenants

default hubs := []

hubs := data.pr.hubs

default landing_zones := []

landing_zones := data.pr.landing_zones

slug := `^[a-z0-9]+(-[a-z0-9]+)*$`

fqdn := `^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,63}$`

# Field rules per list: a pattern for a string, or "cidr", "array", "object".
schemas := {
	"owners": {"file": "owners.yaml", "section": 9, "required": {"slug", "kind", "code", "state"}, "fields": {
		"slug": slug, "kind": `^(customer|product)$`, "code": `^[a-z]{2,3}$`, "state": `^(active|retired)$`,
	}},
	"regions": {"file": "regions.yaml", "section": 10, "required": {"name", "cloud", "code", "state"}, "fields": {
		"name": slug, "cloud": `^(azure|gcp)$`, "code": `^[a-z0-9]{2,4}$`, "state": `^(active|retired)$`,
	}},
	"repos": {"file": "repos.yaml", "section": 11, "required": {"name", "product", "template", "maintainers", "state"}, "fields": {
		"name": slug, "product": slug, "customer": slug, "template": `^tl-template-(spa|saas)$`,
		"maintainers": "array", "state": `^(active|archived)$`, "archived_on": `^[0-9]{4}-[0-9]{2}-[0-9]{2}$`,
	}},
	"domains": {"file": "tenants.yaml", "section": 2, "required": {"name", "owner"}, "fields": {
		"name": fqdn, "owner": slug,
	}},
	"tenants": {"file": "tenants.yaml", "section": 2, "required": {"name", "customer", "stamp"}, "fields": {
		"name": `^[a-z0-9-]{1,40}$`, "customer": slug, "stamp": `^[a-z0-9-]+/[a-z0-9-]+$`, "hostnames": "array",
	}},
	"hubs": {"file": "ipam.yaml", "section": 5, "required": {"name", "cloud", "region", "cidr"}, "fields": {
		"name": `^(vnet|snet)-hub-[a-z0-9]{2,4}$`, "cloud": `^(azure|gcp)$`, "region": slug, "cidr": "cidr", "subnets": "object",
	}},
	"landing_zones": {"file": "ipam.yaml", "section": 5, "required": {"name", "cidr"}, "fields": {
		"name": slug, "cidr": "cidr", "stamps": "object",
	}},
}

lists := {
	"owners": owners, "regions": regions, "repos": repos, "domains": domains,
	"tenants": tenants, "hubs": hubs, "landing_zones": landing_zones,
}

where(list) := sprintf("catalog/%s", [schemas[list].file])

# Reserved tokens that are not region codes (03 section 3).
reserved := {
	"root", "platform", "landingzones", "lz", "products", "cust", "prdt", "shr",
	"prod", "sandbox", "sb", "dev", "test", "uat", "perf", "demo", "staging",
	"experiment", "exp", "global", "standard", "regulated", "experiments", "decommissioned",
}

customer_slugs := {o.slug | some o in owners; o.kind == "customer"}

product_slugs := {o.slug | some o in owners; o.kind == "product"}

# ---- Schema (07 sections 2, 5, 9, 10 and 11) ----

deny contains msg if {
	some list, entries in lists
	not is_array(entries)
	msg := sprintf("%s: %s must be a list (07 section %d)", [where(list), list, schemas[list].section])
}

deny contains msg if {
	some list, entries in lists
	some i, entry in entries
	not is_object(entry)
	msg := sprintf("%s: %s[%d] must be a map (07 section %d)", [where(list), list, i, schemas[list].section])
}

deny contains msg if {
	some list, entries in lists
	some i, entry in entries
	is_object(entry)
	some field in schemas[list].required
	not field in object.keys(entry)
	msg := sprintf("%s: %s[%d] has no %s (07 section %d)", [where(list), list, i, field, schemas[list].section])
}

deny contains msg if {
	some list, entries in lists
	some i, entry in entries
	is_object(entry)
	some field, _ in entry
	not schemas[list].fields[field]
	msg := sprintf("%s: %s[%d] has the unknown field %s (07 section %d)", [where(list), list, i, field, schemas[list].section])
}

deny contains msg if {
	some list, entries in lists
	some i, entry in entries
	is_object(entry)
	some field, value in entry
	rule := schemas[list].fields[field]
	not valid(rule, value)
	msg := sprintf("%s: %s[%d].%s is %v, which is not allowed (07 section %d)", [where(list), list, i, field, value, schemas[list].section])
}

valid("array", value) if is_array(value)

valid("object", value) if is_object(value)

valid("cidr", value) if cidr(value)

valid(rule, value) if {
	not rule in {"array", "object", "cidr"}
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
	some [list, key] in [["owners", "slug"], ["owners", "code"], ["regions", "code"], ["repos", "name"], ["domains", "name"], ["hubs", "name"], ["landing_zones", "name"]]
	some v in duplicates(list, key)
	msg := sprintf("%s: the %s %v is used more than once (07 section %d)", [where(list), key, v, schemas[list].section])
}

# ---- owners.yaml and regions.yaml (07 sections 9 and 10, 03 section 3) ----

deny contains msg if {
	some o in owners
	o.code in reserved
	msg := sprintf("catalog/owners.yaml: the code %v of %v is a reserved token (03 section 3)", [o.code, o.slug])
}

deny contains msg if {
	some o in owners
	some r in regions
	o.code == r.code
	msg := sprintf("catalog/owners.yaml: the code %v of %v is also the code of the region %v (03 section 3)", [o.code, o.slug, r.name])
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

# ---- repos.yaml (07 section 11) ----

deny contains msg if {
	some r in repos
	r.product != r.name
	msg := sprintf("catalog/repos.yaml: %v has the product %v; the two must be equal (07 section 11)", [r.name, r.product])
}

deny contains msg if {
	some r in repos
	not r.product in product_slugs
	msg := sprintf("catalog/repos.yaml: %v names the product %v, which is not a product in catalog/owners.yaml (07 section 11)", [r.name, r.product])
}

deny contains msg if {
	some r in repos
	r.customer
	not r.customer in customer_slugs
	msg := sprintf("catalog/repos.yaml: %v names the customer %v, which is not a customer in catalog/owners.yaml (07 section 11)", [r.name, r.customer])
}

deny contains msg if {
	some r in repos
	is_array(r.maintainers)
	not valid_maintainers(r.maintainers)
	msg := sprintf("catalog/repos.yaml: %v needs at least one maintainer, each a GitHub user name (07 section 11)", [r.name])
}

valid_maintainers(list) if {
	count(list) > 0
	every m in list {
		is_string(m)
		regex.match(`^[A-Za-z0-9](-?[A-Za-z0-9]){0,38}$`, m)
	}
}

deny contains msg if {
	some r in repos
	r.state == "archived"
	not r.archived_on
	msg := sprintf("catalog/repos.yaml: %v is archived and has no archived_on (07 section 11)", [r.name])
}

# ---- tenants.yaml (07 sections 2 and 3) ----

deny contains msg if {
	some d in domains
	not owner_or_trislab(d.owner)
	msg := sprintf("catalog/tenants.yaml: the domain %v has the owner %v, which is neither a customer in catalog/owners.yaml nor trislab (07 section 2.1)", [d.name, d.owner])
}

deny contains msg if {
	some t in tenants
	not owner_or_trislab(t.customer)
	msg := sprintf("catalog/tenants.yaml: the tenant %v on %v has the customer %v, which is neither a customer in catalog/owners.yaml nor trislab (07 section 2.2)", [t.name, t.stamp, t.customer])
}

owner_or_trislab(s) if s == "trislab"

owner_or_trislab(s) if s in customer_slugs

deny contains msg if {
	some t in tenants
	count([x | some x in tenants; x.name == t.name; x.stamp == t.stamp]) > 1
	msg := sprintf("catalog/tenants.yaml: the tenant %v is on %v more than once (07 section 2.2)", [t.name, t.stamp])
}

# A tenant on a stamp in a customer landing zone belongs to that customer.
deny contains msg if {
	some t in tenants
	is_string(t.stamp)
	code := customer_code(t.stamp)
	not t.customer in {o.slug | some o in owners; o.kind == "customer"; o.code == code}
	msg := sprintf("catalog/tenants.yaml: the tenant %v on %v must have the customer whose code is %v (07 section 7)", [t.name, t.stamp, code])
}

customer_code(stamp) := m[0][1] if {
	m := regex.find_all_string_submatch_n(`^cust-([a-z]{2,3})-`, stamp, 1)
	count(m) == 1
}

# [tenant, stamp, customer, i, hostname] for every hostname.
hostnames contains [t.name, t.stamp, t.customer, i, h] if {
	some t in tenants
	is_array(t.hostnames)
	some i, h in t.hostnames
}

deny contains msg if {
	some [name, stamp, _, i, h] in hostnames
	not valid_hostname(h)
	msg := sprintf("catalog/tenants.yaml: hostnames[%d] of %v on %v must be { fqdn, app } with a lowercase FQDN and an app name (07 section 2.2)", [i, name, stamp])
}

valid_hostname(h) if {
	is_object(h)
	object.keys(h) == {"fqdn", "app"}
	is_string(h.fqdn)
	regex.match(fqdn, h.fqdn)
	is_string(h.app)
	regex.match(slug, h.app)
}

all_fqdns := [h.fqdn | some [_, _, _, _, h] in hostnames]

deny contains msg if {
	some f in {f | some f in all_fqdns}
	count([x | some x in all_fqdns; x == f]) > 1
	msg := sprintf("catalog/tenants.yaml: the hostname %v is used more than once (07 section 2.2)", [f])
}

deny contains msg if {
	some [name, stamp, _, _, h] in hostnames
	is_string(h.fqdn)
	not domain_of(h.fqdn)
	msg := sprintf("catalog/tenants.yaml: the hostname %v of %v on %v is in no domain of domains (07 section 3.2)", [h.fqdn, name, stamp])
}

deny contains msg if {
	some [name, stamp, customer, _, h] in hostnames
	d := domain_of(h.fqdn)
	owner := {x.owner | some x in domains; x.name == d}
	count(owner & {customer, "trislab"}) == 0
	msg := sprintf("catalog/tenants.yaml: the hostname %v of %v on %v is in %v, which belongs to another customer (07 section 3.2)", [h.fqdn, name, stamp, d])
}

# At most one label below its domain, so the universal certificate covers it.
deny contains msg if {
	some [name, stamp, _, _, h] in hostnames
	d := domain_of(h.fqdn)
	h.fqdn != d
	contains(trim_suffix(h.fqdn, concat("", [".", d])), ".")
	msg := sprintf("catalog/tenants.yaml: the hostname %v of %v on %v is more than one label below %v (07 section 3)", [h.fqdn, name, stamp, d])
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

deny contains msg if {
	some m in data.main.owners
	not m.slug in {o.slug | some o in owners}
	msg := sprintf("catalog/owners.yaml: %v was removed or renamed; an owner is retired with state: retired, never deleted (07 section 9)", [m.slug])
}

deny contains msg if {
	some m in data.main.owners
	some o in owners
	o.slug == m.slug
	o.code != m.code
	msg := sprintf("catalog/owners.yaml: the code of %v changed from %v to %v; a code never changes (07 section 9)", [m.slug, m.code, o.code])
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
	some m in data.main.repos
	not m.name in {r.name | some r in repos}
	msg := sprintf("catalog/repos.yaml: %v was removed or renamed; a repository is archived with state: archived, never deleted (07 section 11)", [m.name])
}
