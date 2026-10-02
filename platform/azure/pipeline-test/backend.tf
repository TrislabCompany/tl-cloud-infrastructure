# The workflows pass storage_account_name, container_name and key at init
# (08-pipeline.md section 2). The state is encrypted through TF_ENCRYPTION
# (ADR 0046).
terraform {
  backend "azurerm" {
    key              = "pipeline-test.tfstate"
    use_oidc         = true
    use_azuread_auth = true
  }
}
