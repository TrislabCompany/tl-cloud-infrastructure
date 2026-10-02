# Test root of the phase 2 exit check. Removed again in step A7.
resource "azurerm_resource_group" "pipeline_test" {
  name     = "rg-platform-pipelinetest"
  location = var.location

  tags = {
    Product         = "platform"
    Customer        = "trislab"
    EnvironmentType = "prod"
    EnvironmentName = "prod"
  }
}

# Phase 2 guard test (step A5.2): policy/trusted-code.rego must stop this before any sign-in. Not merged.
resource "terraform_data" "code_guard_test" {
  provisioner "local-exec" {
    command = "echo should never run"
  }
}
