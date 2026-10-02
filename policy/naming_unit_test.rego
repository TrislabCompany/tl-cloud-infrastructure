package naming

catalog := {
	"owners": [
		{"slug": "website-trislab", "kind": "product", "code": "web", "state": "active"},
		{"slug": "construction", "kind": "product", "code": "con", "state": "active"},
		{"slug": "okna-capris", "kind": "customer", "code": "oc", "state": "active"},
		{"slug": "astra-group", "kind": "customer", "code": "asg", "state": "active"},
		{"slug": "rehabo", "kind": "customer", "code": "reh", "state": "retired"},
	],
	"regions": [
		{"name": "northeurope", "cloud": "azure", "code": "neu", "state": "active"},
		{"name": "italynorth", "cloud": "azure", "code": "itn", "state": "retired"},
	],
}

plan(type, after) := {"resource_changes": [{
	"address": sprintf("%s.this", [type]),
	"mode": "managed",
	"type": type,
	"change": {"actions": ["create"], "after": after},
}]}

denied(type, after) := d if {
	d := deny with input as plan(type, after) with data.pr as catalog
}

test_pipeline_test_resource_group_passes if {
	count(denied("azurerm_resource_group", {"name": "rg-platform-pipelinetest"})) == 0
}

test_good_names_pass if {
	every pair in [
		["azurerm_resource_group", "rg-hub-neu"],
		["azurerm_resource_group", "rg-cust-oc-prod-neu-network"],
		["azurerm_resource_group", "rg-products-sandbox-neu-02-security"],
		["azurerm_resource_group", "rg-oc-con-prod"],
		["azurerm_resource_group", "rg-shr-web-staging"],
		["azurerm_resource_group", "rg-con-prod"],
		["azurerm_resource_group", "rg-shr-con-prod-01"],
		["azurerm_virtual_network", "vnet-hub-neu"],
		["azurerm_virtual_network", "vnet-cust-asg-sandbox-neu"],
		["azurerm_subnet", "GatewaySubnet"],
		["azurerm_subnet", "snet-oc-con-pr142"],
		["azurerm_key_vault", "kv-platform-1307"],
		["azurerm_key_vault", "kv-cust-asg-sandbox-4821"],
		["azurerm_key_vault", "kv-prdt-con-sb-4821"],
		["azurerm_storage_account", "stplatformtfstate6884"],
		["azurerm_storage_account", "stocconprod5530"],
		["azurerm_container_app", "ca-oc-con-prod-web"],
		["azurerm_key_vault_secret", "oc-con-prod-origin-trislab-com"],
		["azurerm_key_vault_secret", "contacts-oc"],
		["azurerm_key_vault_secret", "tofu-passphrase-stamps"],
		["azurerm_user_assigned_identity", "id-oc-con-prod-appdeploy"],
		["azurerm_management_lock", "lock-rg-platform-state"],
		["azurerm_monitor_action_group", "ag-finops"],
		["azuread_group", "grp-data-cust-asg-prod-neu-readers"],
	] {
		count(denied(pair[0], {"name": pair[1], "display_name": pair[1]})) == 0
	}
}

test_bad_pattern_is_denied if {
	some msg in denied("azurerm_resource_group", {"name": "rg-pipelinetest"})
	contains(msg, "doesn't match a name pattern")
}

test_company_token_is_denied if {
	some msg in denied("azurerm_resource_group", {"name": "rg-tl-platform-state"})
	contains(msg, "doesn't match a name pattern")
}

test_unregistered_owner_code_is_denied if {
	some msg in denied("azurerm_resource_group", {"name": "rg-cust-vbs-prod-neu-network"})
	contains(msg, "isn't active in catalog/")
}

test_retired_owner_code_is_denied if {
	some msg in denied("azurerm_virtual_network", {"name": "vnet-cust-reh-prod-neu"})
	contains(msg, "isn't active in catalog/")
}

test_retired_region_code_is_denied if {
	some msg in denied("azurerm_virtual_network", {"name": "vnet-hub-itn"})
	contains(msg, "isn't active in catalog/")
}

test_too_long_name_is_denied if {
	some msg in denied("azurerm_key_vault", {"name": "kv-products-sandbox-48210"})
	contains(msg, "doesn't match a name pattern")
	cat := {"owners": [{"slug": "x", "kind": "customer", "code": "abc", "state": "active"}, {"slug": "y", "kind": "product", "code": "con", "state": "active"}], "regions": []}
	some long in deny with input as plan("azurerm_container_app", {"name": "ca-abc-con-staging-01-frontendapp"}) with data.pr as cat
	contains(long, "characters, outside 2 to 32")
}

test_unknown_name_is_not_checked if {
	count(denied("azurerm_key_vault", {"tags": {}})) == 0
}

test_type_without_pattern_is_not_checked if {
	count(denied("azurerm_role_assignment", {"name": "00000000-0000-0000-0000-000000000000"})) == 0
}

test_update_is_not_checked if {
	p := {"resource_changes": [{"address": "a", "mode": "managed", "type": "azurerm_resource_group", "change": {"actions": ["update"], "after": {"name": "legacy"}}}]}
	count(deny) == 0 with input as p with data.pr as catalog
}

test_replace_is_checked if {
	p := {"resource_changes": [{"address": "a", "mode": "managed", "type": "azurerm_resource_group", "change": {"actions": ["delete", "create"], "after": {"name": "legacy"}}}]}
	count(deny) > 0 with input as p with data.pr as catalog
}

test_subscription_alias_and_display_name_are_checked if {
	count(denied("azurerm_subscription", {"alias": "sub-products-sandbox-neu", "subscription_name": "sub-products-sandbox-neu"})) == 0
	some msg in denied("azurerm_subscription", {"alias": "sub-products-sandbox-neu", "subscription_name": "Products sandbox"})
	contains(msg, "differ")
}

test_management_group_display_name if {
	count(denied("azurerm_management_group", {"name": "mg-root", "display_name": "Trislab"})) == 0
	some msg in denied("azurerm_management_group", {"name": "mg-platform", "display_name": "Platform"})
	contains(msg, "should be \"mg-platform\"")
}

test_entra_display_names_are_checked if {
	count(denied("azuread_application", {"display_name": "spn-lz-cust-oc-prod-neu-deploy"})) == 0
	count(denied("azuread_application", {"display_name": "tl-github-plan"})) > 0
}

test_no_owners_matches_no_owner_code if {
	some msg in deny with input as plan("azurerm_resource_group", {"name": "rg-oc-con-prod"}) with data.pr as {"owners": [], "regions": []}
	contains(msg, "isn't active in catalog/")
}
