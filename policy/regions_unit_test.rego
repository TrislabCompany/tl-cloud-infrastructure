package regions

catalog := {"regions": [
	{"name": "northeurope", "cloud": "azure", "code": "neu", "state": "active"},
	{"name": "italynorth", "cloud": "azure", "code": "itn", "state": "retired"},
	{"name": "europe-west8", "cloud": "gcp", "code": "euw8", "state": "active"},
]}

plan(type, after) := {"resource_changes": [{
	"address": sprintf("%s.this", [type]),
	"mode": "managed",
	"type": type,
	"change": {"actions": ["create"], "after": after},
}]}

test_catalog_regions_pass if {
	count(deny) == 0 with input as {} with data.pr as catalog
}

test_non_eu_azure_region_is_denied if {
	some msg in deny with input as {} with data.pr as {"regions": [{"name": "switzerlandnorth", "cloud": "azure", "code": "chn", "state": "active"}]}
	msg == "catalog/regions.yaml: azure region switzerlandnorth is not in an EU member state (N6)"
}

test_eea_region_is_denied if {
	count(deny) == 1 with input as {} with data.pr as {"regions": [{"name": "norwayeast", "cloud": "azure", "code": "noe", "state": "active"}]}
}

test_non_eu_gcp_region_is_denied if {
	count(deny) == 1 with input as {} with data.pr as {"regions": [{"name": "europe-west2", "cloud": "gcp", "code": "euw2", "state": "active"}]}
}

test_region_of_other_cloud_is_denied if {
	count(deny) == 1 with input as {} with data.pr as {"regions": [{"name": "europe-west8", "cloud": "azure", "code": "euw8", "state": "active"}]}
}

test_active_location_passes if {
	count(deny) == 0 with input as plan("azurerm_resource_group", {"location": "northeurope"}) with data.pr as catalog
}

test_display_location_is_normalized if {
	count(deny) == 0 with input as plan("azurerm_resource_group", {"location": "North Europe"}) with data.pr as catalog
}

test_global_location_passes if {
	count(deny) == 0 with input as plan("azurerm_monitor_action_group", {"location": "global"}) with data.pr as catalog
}

test_unlisted_location_is_denied if {
	some msg in deny with input as plan("azurerm_resource_group", {"location": "westeurope"}) with data.pr as catalog
	contains(msg, "is not an active azure region")
}

test_retired_location_is_denied if {
	count(deny) == 1 with input as plan("azurerm_resource_group", {"location": "italynorth"}) with data.pr as catalog
}

test_azapi_location_is_checked if {
	count(deny) == 1 with input as plan("azapi_resource", {"location": "eastus"}) with data.pr as catalog
}

test_no_location_is_not_checked if {
	count(deny) == 0 with input as plan("azurerm_management_group", {"name": "mg-root"}) with data.pr as catalog
}
