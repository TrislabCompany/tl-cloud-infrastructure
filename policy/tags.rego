# Tag rules, run on the JSON plan (03 sections 9 and 11).
#
#   conftest test plan.json --policy <main checkout>/policy --data <catalogs> --namespace tags
#
# Every Azure resource a plan creates or updates that takes tags carries the
# four tags, with allowed values. A tag whose value stays unknown until apply
# counts as present. GCP labels wait for the first GCP customer (ADR 0008).
package tags

default owners := []

owners := data.pr.owners

required := ["Product", "Customer", "EnvironmentType", "EnvironmentName"]

slugs(kind) := {o.slug | some o in owners; o.kind == kind}

allowed := {
	"EnvironmentType": {"prod", "sandbox"},
	"Customer": slugs("customer") | {"trislab"},
	"Product": slugs("product") | {"platform"},
}

# [address, known tags, unknown tags] of every tagged resource that changes.
tagged contains [rc.address, as_object(rc.change.after.tags), as_object(unknown)] if {
	some rc in input.resource_changes
	rc.mode == "managed"
	startswith(rc.type, "azurerm_")
	some action in rc.change.actions
	action in {"create", "update"}
	"tags" in object.keys(rc.change.after)
	unknown := object.get(rc.change, ["after_unknown", "tags"], {})
	unknown != true
}

deny contains msg if {
	some [address, tags, unknown] in tagged
	some tag in required
	not tag in object.keys(tags)
	not unknown[tag]
	msg := sprintf("%s: the tag %s is missing (03 section 9)", [address, tag])
}

deny contains msg if {
	some [address, tags, _] in tagged
	some tag, values in allowed
	is_string(tags[tag])
	not tags[tag] in values
	msg := sprintf("%s: the tag %s is %q, not one of %v (03 section 9, catalog/owners.yaml)", [address, tag, tags[tag], sort(values)])
}

# dev, test, uat, perf, demo, staging, pr<n> and prod name a stamp's environment;
# sandbox and experiment a landing zone's own resources (03 section 9).
environment_names := {"dev", "test", "uat", "perf", "demo", "staging", "prod", "sandbox", "experiment"}

deny contains msg if {
	some [address, tags, _] in tagged
	is_string(tags.EnvironmentName)
	not tags.EnvironmentName in environment_names
	not regex.match(`^pr[1-9][0-9]*$`, tags.EnvironmentName)
	msg := sprintf("%s: the tag EnvironmentName is %q, not one of %v or pr<n> (03 section 9)", [address, tags.EnvironmentName, sort(environment_names)])
}

as_object(x) := x if is_object(x)

as_object(x) := {} if not is_object(x)
