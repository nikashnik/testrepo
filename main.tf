provider "azurerm" {
  features {}
}

provider "random" {
  # Configuration options
}

# Generate random strings for naming
resource "random_string" "suffix" {
  length  = 8
  upper   = false
  special = false
}

module "backend" {
  source              = "./backend_module"
  resource_group_name = azurerm_resource_group.demo.name
  storage_account_name = "demostrgacnt${random_string.suffix.result}"
  container_name      = "tfstate${random_string.suffix.result}"
  key                 = "terraform.tfstate"
}

# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }

  required_version = ">= 1.1.0"
}

# Create Resource Group
resource "azurerm_resource_group" "demo" {
  name     = "demo-resources"
  location = "West Europe"
}

# Create Storage Account
resource "azurerm_storage_account" "demo" {
  name                     = "demostrgacnt${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.demo.name
  location                 = azurerm_resource_group.demo.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  identity {
    type = "SystemAssigned"
  }
}

# Create Storage Container
resource "azurerm_storage_container" "demo" {
  name                  = "tfstate${random_string.suffix.result}"
  storage_account_name  = azurerm_storage_account.demo.name
  container_access_type = "private"
}

# App Service Plan and App Service

resource "azurerm_app_service_plan" "demo" {
  name                = "demoappserviceplan${random_string.suffix.result}"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  sku {
    tier = "Basic"
    size = "B1"
  }
}

resource "azurerm_app_service" "demo" {
  name                = "demoappservice${random_string.suffix.result}"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  app_service_plan_id = azurerm_app_service_plan.demo.id

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    "WEBSITE_RUN_FROM_PACKAGE" = "1"
  }
}

resource "azurerm_role_assignment" "demo" {
  principal_id         = azurerm_app_service.demo.identity[0].principal_id
  role_definition_name = "Contributor"
  scope                = azurerm_resource_group.demo.id
}
