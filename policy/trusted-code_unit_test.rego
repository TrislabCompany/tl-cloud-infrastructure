package trusted_code

good_root := {
	"terraform": [{
		"backend": {"azurerm": [{"use_azuread_auth": true}]},
		"required_providers": [{"azurerm": {"source": "hashicorp/azurerm", "version": "~> 4.0"}}],
	}],
	"provider": {"azurerm": [{"features": [{}], "storage_use_azuread": true}]},
	"resource": {
		"azurerm_resource_group": {"rg": [{"name": "rg-platform-pipelinetest"}]},
		"terraform_data": {"marker": [{"input": "x"}]},
	},
	"module": {
		"local": [{"source": "../modules/x"}],
		"platform": [{"source": "git::https://github.com/TrislabCompany/tl-platform.git//modules/landing-zone?ref=v1.0.0"}],
	},
}

test_good_root_passes if {
	count(deny) == 0 with input as good_root
}

test_local_exec_is_denied if {
	some msg in deny with input as {"resource": {"terraform_data": {"x": [{"provisioner": {"local-exec": [{"command": "id"}]}}]}}}
	startswith(msg, "provisioners are not allowed")
}

test_remote_exec_is_denied if {
	some msg in deny with input as {"resource": {"azurerm_linux_virtual_machine": {"vm": [{"provisioner": {"remote-exec": [{"inline": ["id"]}]}}]}}}
	startswith(msg, "provisioners are not allowed")
}

test_external_data_source_is_denied if {
	some msg in deny with input as {"data": {"external": {"e": [{"program": ["sh"]}]}}}
	startswith(msg, "the external data source is not allowed")
}

test_external_data_source_in_check_block_is_denied if {
	some msg in deny with input as {"check": {"c": [{"data": {"external": {"e": [{"program": ["sh"]}]}}}]}}
	startswith(msg, "the external data source is not allowed")
}

test_unlisted_required_provider_is_denied if {
	some msg in deny with input as {"terraform": [{"required_providers": [{"null": {"source": "hashicorp/null"}}]}]}
	msg == `provider "null" is not on the allow-list`
}

test_allowed_name_with_other_source_is_denied if {
	some msg in deny with input as {"terraform": [{"required_providers": [{"azurerm": {"source": "evil/azurerm"}}]}]}
	contains(msg, "has a source that is not on the allow-list")
}

test_registry_prefix_is_accepted if {
	count(deny) == 0 with input as {"terraform": [{"required_providers": [{"azurerm": {"source": "registry.opentofu.org/hashicorp/azurerm"}}]}]}
}

test_unlisted_provider_block_is_denied if {
	some msg in deny with input as {"provider": {"http": [{}]}}
	msg == `provider "http" is not on the allow-list`
}

test_implicit_provider_resource_is_denied if {
	some msg in deny with input as {"resource": {"null_resource": {"x": [{}]}}}
	contains(msg, `resource type "null_resource"`)
}

test_unlisted_data_source_is_denied if {
	some msg in deny with input as {"data": {"http": {"x": [{"url": "https://example.com"}]}}}
	contains(msg, `data type "http"`)
}

test_other_module_source_is_denied if {
	some msg in deny with input as {"module": {"m": [{"source": "git::https://github.com/someone/else.git"}]}}
	contains(msg, "has a source other than tl-platform")
}

test_lookalike_module_source_is_denied if {
	some msg in deny with input as {"module": {"m": [{"source": "github.com/TrislabCompany/tl-platform-fork//modules/x"}]}}
	contains(msg, "has a source other than tl-platform")
}

test_registry_module_source_is_denied if {
	some msg in deny with input as {"module": {"m": [{"source": "Azure/avm-res-resources-resourcegroup/azurerm"}]}}
	contains(msg, "has a source other than tl-platform")
}
