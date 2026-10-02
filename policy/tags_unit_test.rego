package tags

catalog := {"owners": [
	{"slug": "website-trislab", "kind": "product", "code": "web", "state": "active"},
	{"slug": "okna-capris", "kind": "customer", "code": "oc", "state": "active"},
]}

good_tags := {"Product": "platform", "Customer": "trislab", "EnvironmentType": "prod", "EnvironmentName": "prod"}

plan(type, actions, after, unknown) := {"resource_changes": [{
	"address": sprintf("%s.this", [type]),
	"mode": "managed",
	"type": type,
	"change": {"actions": actions, "after": after, "after_unknown": unknown},
}]}

denied(after) := d if {
	d := deny with input as plan("azurerm_resource_group", ["create"], after, {}) with data.pr as catalog
}

test_pipeline_test_tags_pass if {
	count(denied({"name": "rg-platform-pipelinetest", "tags": good_tags})) == 0
}

test_owner_slugs_pass if {
	count(denied({"tags": {"Product": "website-trislab", "Customer": "okna-capris", "EnvironmentType": "sandbox", "EnvironmentName": "pr142"}})) == 0
}

test_missing_tag_is_denied if {
	some msg in denied({"tags": object.remove(good_tags, ["EnvironmentName"])})
	msg == "azurerm_resource_group.this: the tag EnvironmentName is missing (03 section 9)"
}

test_no_tags_denies_all_four if {
	count(denied({"tags": null})) == 4
}

test_nonprod_is_denied if {
	some msg in denied({"tags": object.union(good_tags, {"EnvironmentType": "nonprod"})})
	contains(msg, "the tag EnvironmentType is \"nonprod\"")
}

test_unregistered_customer_is_denied if {
	some msg in denied({"tags": object.union(good_tags, {"Customer": "vbs-lawyers"})})
	contains(msg, "the tag Customer is \"vbs-lawyers\"")
}

test_product_slug_as_customer_is_denied if {
	some msg in denied({"tags": object.union(good_tags, {"Customer": "website-trislab"})})
	contains(msg, "the tag Customer")
}

test_unknown_tag_value_counts_as_present if {
	p := plan("azurerm_resource_group", ["create"], {"tags": object.remove(good_tags, ["Product"])}, {"tags": {"Product": true}})
	count(deny) == 0 with input as p with data.pr as catalog
}

test_update_is_checked if {
	p := plan("azurerm_resource_group", ["update"], {"tags": {}}, {})
	count(deny) == 4 with input as p with data.pr as catalog
}

test_delete_is_not_checked if {
	p := plan("azurerm_resource_group", ["delete"], null, {})
	count(deny) == 0 with input as p with data.pr as catalog
}

test_resource_without_tags_is_not_checked if {
	p := plan("azurerm_role_assignment", ["create"], {"scope": "/"}, {})
	count(deny) == 0 with input as p with data.pr as catalog
}

test_entra_tags_are_not_checked if {
	p := plan("azuread_application", ["create"], {"tags": ["x"]}, {})
	count(deny) == 0 with input as p with data.pr as catalog
}
