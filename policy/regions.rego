# Region rules (07 sections 7 and 10, N6).
#
#   conftest test plan.json --policy <main checkout>/policy --data <catalogs> --namespace regions
#
# Every entry in catalog/regions.yaml is a region in an EU member state, and
# every Azure resource a plan creates or updates is in an active region from
# that file. The lists below name the regions located in EU member states.
# Regions in other EEA countries, Switzerland and the United Kingdom are not on
# them. They change only by a PR the governance owner approves (14 section 3).
# GCP resource locations wait for the first GCP customer (ADR 0008).
package regions

default regions := []

regions := data.pr.regions

eu_regions := {
	"azure": {
		"austriaeast", "belgiumcentral", "denmarkeast", "francecentral",
		"francesouth", "germanynorth", "germanywestcentral", "italynorth",
		"northeurope", "polandcentral", "spaincentral", "swedencentral",
		"westeurope",
	},
	"gcp": {
		"europe-central2", "europe-north1", "europe-north2", "europe-southwest1",
		"europe-west1", "europe-west3", "europe-west4", "europe-west8",
		"europe-west9", "europe-west10", "europe-west12",
	},
}

deny contains msg if {
	some r in regions
	not r.name in object.get(eu_regions, r.cloud, set())
	msg := sprintf("catalog/regions.yaml: %v region %v is not in an EU member state (N6)", [r.cloud, r.name])
}

active_azure := {r.name | some r in regions; r.cloud == "azure"; r.state == "active"}

deny contains msg if {
	some rc in input.resource_changes
	rc.mode == "managed"
	some prefix in ["azurerm_", "azapi_"]
	startswith(rc.type, prefix)
	some action in rc.change.actions
	action in {"create", "update"}
	is_string(rc.change.after.location)
	location := lower(replace(rc.change.after.location, " ", ""))
	location != "global"
	not location in active_azure
	msg := sprintf("%s: the location %q is not an active azure region in catalog/regions.yaml (07 section 10)", [rc.address, rc.change.after.location])
}
