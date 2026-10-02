# Name rules, run on the JSON plan (03 section 11).
#
#   conftest test plan.json --policy <main checkout>/policy --data <catalogs> --namespace naming
#
# Every name a plan creates must match a pattern of its resource type
# (03 sections 5 to 7), built from the active owner and region codes in
# catalog/, and stay within its length limit (03 section 10). Types with no
# pattern in 03 are not checked. A name that stays unknown until apply, such as
# one with a suffix from a random_integer of the same plan, can't be checked here.
# GCP patterns wait for the first GCP customer (ADR 0008).
package naming

default owners := []

owners := data.pr.owners

default regions := []

regions := data.pr.regions

# Placeholders: {lz} a landing zone, {kvscope} a Key Vault scope, {stamp} a
# stamp code, {stampcompact} a stamp code without hyphens (03 section 7).
patterns := {
	"azurerm_management_group": [
		"mg-root", "mg-platform", "mg-landingzones", "mg-lz-standard",
		"mg-lz-regulated", "mg-experiments", "mg-decommissioned",
	],
	"azurerm_subscription": [
		"sub-platform(?:-connectivity|-management|-apps)?",
		"sub-{lz}",
		"sub-exp-[a-z0-9]{2,12}",
	],
	"azurerm_resource_group": [
		"rg-platform-{purpose}",
		"rg-hub-{region}",
		"rg-{lz}-(?:network|security|monitoring)",
		"rg-{stamp}",
	],
	"azurerm_virtual_network": ["vnet-hub-{region}", "vnet-{lz}"],
	"azurerm_subnet": ["GatewaySubnet", "snet-{stamp}"],
	"azurerm_network_security_group": ["nsg-{stamp}"],
	"azurerm_network_watcher": ["nw-{lz}"],
	"azurerm_public_ip": ["pip-vgw-hub-{region}"],
	"azurerm_virtual_network_gateway": ["vgw-hub-{region}"],
	"azurerm_virtual_network_gateway_connection": ["conn-hub-{region}-to-gcp"],
	"azurerm_key_vault": ["kv-platform-{nnnn}", "kv-{kvscope}-{nnnn}"],
	"azurerm_key_vault_secret": [
		"contacts-{cust}",
		"tofu-passphrase-(?:global|platform|landingzones|stamps)",
		"{stamp}-{purpose}(?:-{purpose})*",
	],
	"azurerm_storage_account": ["stplatformtfstate{nnnn}", "st{stampcompact}{nnnn}"],
	"azurerm_log_analytics_workspace": ["log-platform", "log-{lz}"],
	"azurerm_monitor_action_group": ["ag-finops", "ag-platform"],
	"azurerm_consumption_budget_subscription": ["budget-{lz}"],
	"azurerm_management_lock": ["lock-{purpose}(?:-{purpose})*"],
	"azurerm_container_app_environment": ["cae-{stamp}"],
	"azurerm_container_app": ["ca-{stamp}-{app}"],
	"azurerm_kubernetes_cluster": ["aks-{stamp}"],
	"azurerm_linux_function_app": ["func-{stamp}-{nnnn}"],
	"azurerm_windows_function_app": ["func-{stamp}-{nnnn}"],
	"azurerm_postgresql_flexible_server": ["psql-{stamp}-{nnnn}"],
	"azurerm_mssql_server": ["sql-{stamp}-{nnnn}"],
	"azurerm_mssql_database": ["sqldb-{stamp}"],
	"azurerm_user_assigned_identity": ["id-backstage", "id-{stamp}-(?:workload|appdeploy)"],
	"azuread_application": [
		"spn-(?:platform|global|landingzones)-(?:plan|apply)",
		"spn-lz-{lz}-(?:plan|deploy)",
	],
	"azuread_group": [
		"grp-devops", "grp-platform-admins", "grp-regulated-admins",
		"grp-cust-{cust}-admins",
		"grp-data-sandbox-(?:readers|admins)",
		"grp-data-{lz}-(?:readers|admins)",
	],
}

# 03 section 10, for the types above.
limits := {
	"azurerm_management_group": [1, 90],
	"azurerm_resource_group": [1, 90],
	"azurerm_virtual_network": [2, 64],
	"azurerm_key_vault": [3, 24],
	"azurerm_storage_account": [3, 24],
	"azurerm_postgresql_flexible_server": [3, 63],
	"azurerm_linux_function_app": [2, 60],
	"azurerm_windows_function_app": [2, 60],
	"azurerm_log_analytics_workspace": [4, 63],
	"azurerm_container_app_environment": [2, 60],
	"azurerm_container_app": [2, 32],
	"azurerm_key_vault_secret": [1, 127],
	"azurerm_kubernetes_cluster": [1, 63],
	"azurerm_user_assigned_identity": [3, 128],
}

# The attributes that hold the name, where it isn't `name`.
name_attributes := {
	"azurerm_subscription": ["alias", "subscription_name"],
	"azuread_application": ["display_name"],
	"azuread_group": ["display_name"],
}

compound := {
	"{lz}": "(?:products|cust-{cust}|prdt-{prod})-(?:prod|sandbox)-{region}(?:-(?:0[2-9]|[1-9][0-9]))?",
	"{kvscope}": "(?:products|cust-{cust}|prdt-{prod})-(?:prod|sandbox|sb)",
	"{stamp}": "(?:(?:{cust}|shr)-{prod}|{prod})-{env}(?:-[0-9]{2})?",
	"{stampcompact}": "(?:(?:{cust}|shr){prod}|{prod}){env}(?:[0-9]{2})?",
}

common := {
	"{env}": "(?:dev|test|uat|perf|demo|staging|prod|pr[0-9]+)",
	"{nnnn}": "[1-9][0-9]{3}",
	"{purpose}": "[a-z0-9]+",
	"{app}": "[a-z0-9]+",
}

# Strict: only the codes registered as active in catalog/.
codes(cloud, true) := object.union(common, {
	"{cust}": alternation({o.code | some o in owners; o.kind == "customer"; o.state == "active"}),
	"{prod}": alternation({o.code | some o in owners; o.kind == "product"; o.state == "active"}),
	"{region}": alternation({r.code | some r in regions; r.cloud == cloud; r.state == "active"}),
})

# Loose: any code of the right shape, to tell a bad pattern from an unregistered code.
codes(_, false) := object.union(common, {
	"{cust}": "[a-z]{2,3}",
	"{prod}": "[a-z]{2,3}",
	"{region}": "[a-z0-9]{2,4}",
})

# An empty set matches nothing.
alternation(s) := `[^\s\S]` if count(s) == 0

alternation(s) := sprintf("(?:%s)", [concat("|", sort(s))]) if count(s) > 0

pattern_regex(p, cloud, strict) := sprintf("^%s$", [strings.replace_n(codes(cloud, strict), strings.replace_n(compound, p))])

cloud_of(type) := "gcp" if startswith(type, "google_")

cloud_of(type) := "azure" if not startswith(type, "google_")

matches(type, name, strict) if {
	some p in patterns[type]
	regex.match(pattern_regex(p, cloud_of(type), strict), name)
}

changes(rc, actions) if {
	rc.mode == "managed"
	some action in rc.change.actions
	action in actions
}

new_names contains [rc.address, rc.type, name] if {
	some rc in input.resource_changes
	changes(rc, {"create"})
	patterns[rc.type]
	some attribute in object.get(name_attributes, rc.type, ["name"])
	name := rc.change.after[attribute]
	is_string(name)
}

deny contains msg if {
	some [address, type, name] in new_names
	not matches(type, name, false)
	msg := sprintf("%s: %q doesn't match a name pattern of %s (03 sections 5 to 7)", [address, name, type])
}

deny contains msg if {
	some [address, type, name] in new_names
	matches(type, name, false)
	not matches(type, name, true)
	msg := sprintf("%s: %q uses an owner or region code that isn't active in catalog/ (03 section 4, 07 sections 9 and 10)", [address, name])
}

deny contains msg if {
	some [address, type, name] in new_names
	[low, high] := limits[type]
	not within(count(name), low, high)
	msg := sprintf("%s: %q is %d characters, outside %d to %d for %s (03 section 10)", [address, name, count(name), low, high, type])
}

within(n, low, high) if {
	n >= low
	n <= high
}

# Name and display name are the same; mg-root is shown as "Trislab" (03 section 1, principle 9).
deny contains msg if {
	some rc in input.resource_changes
	rc.type == "azurerm_management_group"
	changes(rc, {"create", "update"})
	is_string(rc.change.after.name)
	is_string(rc.change.after.display_name)
	rc.change.after.display_name != display_name(rc.change.after.name)
	msg := sprintf("%s: the display name %q should be %q (03 section 1, principle 9)", [rc.address, rc.change.after.display_name, display_name(rc.change.after.name)])
}

deny contains msg if {
	some rc in input.resource_changes
	rc.type == "azurerm_subscription"
	changes(rc, {"create", "update"})
	is_string(rc.change.after.alias)
	is_string(rc.change.after.subscription_name)
	rc.change.after.alias != rc.change.after.subscription_name
	msg := sprintf("%s: the alias %q and the display name %q differ (03 section 1, principle 9)", [rc.address, rc.change.after.alias, rc.change.after.subscription_name])
}

display_name("mg-root") := "Trislab"

display_name(name) := name if name != "mg-root"
