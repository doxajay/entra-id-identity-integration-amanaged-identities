terraform {
  required_version = ">= 1.4.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-managed-identity-demo"
  location = "canadacentral"
}

# Key Vault
resource "azurerm_key_vault" "kv" {
  name                = "kv-managed-id-demo123"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tenant_id           = var.tenant_id
  sku_name            = "standard"
}

# Access Policy for Terraform SP (so Terraform can create the secret)
resource "azurerm_key_vault_access_policy" "kv_policy_terraform" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = var.tenant_id
  object_id    = var.client_object_id

  secret_permissions = ["Get", "List", "Set"]
}

# App Service Plan
resource "azurerm_service_plan" "plan" {
  name                = "asp-managed-id-demo"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "B1"
}

# App Service with Managed Identity
resource "azurerm_linux_web_app" "app" {
  name                = "demo-managed-id-app"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.plan.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    app_command_line = ""
  }
}

# Access Policy for the App to read Key Vault secret using Managed Identity
resource "azurerm_key_vault_access_policy" "kv_policy_app" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = var.tenant_id
  object_id    = azurerm_linux_web_app.app.identity[0].principal_id

  secret_permissions = ["Get", "List"]
}

# Secret in Key Vault (Terraform now has access, so this will succeed)
resource "azurerm_key_vault_secret" "demo_secret" {
  name         = "DemoSecret"
  value        = "SuperSecureValue123!"
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [
    azurerm_key_vault_access_policy.kv_policy_terraform,
    azurerm_key_vault_access_policy.kv_policy_app
  ]
}
