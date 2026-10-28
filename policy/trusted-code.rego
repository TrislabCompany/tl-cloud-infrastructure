# Static check of a root's code, run before any sign-in (ADR 0045).
#
#   conftest test --parser hcl2 --policy <main checkout>/policy --namespace trusted_code <files>
#
# Each .tf or .tofu file is checked on its own, as parsed by the hcl2 parser.
package trusted_code

# Providers a root may use, by local name. "terraform" is the built-in
# provider of terraform_data.
allowed_names := {
	"azurerm", "azapi", "azuread", "random", "time", "dns", "tls",
	"cloudflare", "github", "google", "neon", "upstash", "terraform",
}

allowed_sources := {
	"hashicorp/azurerm", "azure/azapi", "hashicorp/azuread", "hashicorp/random",
	"hashicorp/time", "hashicorp/dns", "hashicorp/tls", "cloudflare/cloudflare",
	"integrations/github", "hashicorp/google", "kislerdm/neon", "upstash/upstash",
}

# Module sources: a local path, or a folder of the tl-platform repository at a
# release tag of that folder and nothing else: <module>/v<x.y.z>, where
# <module> is the folder's last path segment, or v<x.y.z> for the landing-zone
# releases before the prefix. Its tags can't be moved (09 section 8), so a tag
# always means the same reviewed code; a branch, a missing ref or another
# folder's tag doesn't.
local_module_pattern := `^\.\.?/`

# Captures the folder and the tag's <module>, empty for a bare v<x.y.z>.
platform_module_pattern := `^(?:git::https://github\.com/TrislabCompany/tl-platform\.git|github\.com/TrislabCompany/tl-platform(?:\.git)?)//([A-Za-z0-9._/-]+)\?ref=(?:([a-z0-9-]+)/)?v[0-9]+\.[0-9]+\.[0-9]+$`

deny contains msg if {
	walk(input, [path, _])
	path[count(path) - 1] == "provisioner"
	msg := sprintf("provisioners are not allowed: %s", [concat(".", [format_segment(p) | some p in path])])
}

deny contains msg if {
	walk(input, [path, value])
	path[count(path) - 1] == "data"
	some name, _ in value.external
	msg := sprintf("the external data source is not allowed: data.external.%s", [name])
}

deny contains msg if {
	some block in input.terraform
	some providers in block.required_providers
	some name, _ in providers
	not name in allowed_names
	msg := sprintf("provider %q is not on the allow-list", [name])
}

deny contains msg if {
	some block in input.terraform
	some providers in block.required_providers
	some name, spec in providers
	not allowed_source(spec)
	msg := sprintf("provider %q has a source that is not on the allow-list: %v", [name, spec])
}

deny contains msg if {
	some name, _ in input.provider
	not name in allowed_names
	msg := sprintf("provider %q is not on the allow-list", [name])
}

deny contains msg if {
	some kind in ["resource", "data", "ephemeral"]
	some type, _ in input[kind]
	not type_prefix(type) in allowed_names
	msg := sprintf("%s type %q belongs to a provider that is not on the allow-list", [kind, type])
}

deny contains msg if {
	some name, blocks in input.module
	some block in blocks
	not allowed_module_source(block.source)
	msg := sprintf("module %q has a source other than a tl-platform release tag or a local path: %v", [name, block.source])
}

allowed_source(spec) if {
	is_object(spec)
	not spec.source
}

allowed_source(spec) if {
	is_object(spec)
	source := trim_prefix(lower(spec.source), "registry.opentofu.org/")
	source in allowed_sources
}

# A short form such as `azurerm = "~> 4.0"` sets only the version.
allowed_source(spec) if is_string(spec)

allowed_module_source(source) if {
	is_string(source)
	regex.match(local_module_pattern, source)
}

allowed_module_source(source) if {
	is_string(source)
	[[_, folder, module]] := regex.find_all_string_submatch_n(platform_module_pattern, source, 1)
	module in {"", last_segment(folder)}
}

last_segment(path) := segments[count(segments) - 1] if segments := split(trim_suffix(path, "/"), "/")

type_prefix(type) := split(type, "_")[0]

format_segment(p) := sprintf("%v", [p])
