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
