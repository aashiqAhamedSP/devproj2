 terraform {
  required_version = ">= 0.11" 
 backend "azurerm" {
  storage_account_name = "__terraformstorageaccount__"
    container_name       = "terraform"
    key                  = "terraform.tfstate"
	access_key  ="__storagekey__"
	}
}

provider "azurerm" {
  features {}

}

resource "azurerm_resource_group" "project2_rg" {
  name     = "__resourcegroupname__"
  location = "__location__"
}

resource "azurerm_app_service_plan" "wolkappplan" {
  name                = "__appserviceplan__"
  location            = azurerm_resource_group.project2_rg.location
  resource_group_name = azurerm_resource_group.project2_rg.name

  sku {
    tier = "Free"
    size = "F1"
  }
}

resource "azurerm_app_service" "wolkwebapp" {
  name                = "__appservicename__"
  location            = azurerm_resource_group.project2_rg.location
  resource_group_name = azurerm_resource_group.project2_rg.name
  app_service_plan_id = azurerm_app_service_plan.wolkappplan.id
}


resource "azurerm_storage_account" "wolkwebappstrg22" {
  name                     = "__logstorage__"
  resource_group_name      = azurerm_resource_group.project2_rg.name
  location                 = azurerm_resource_group.project2_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "wolkwebblbcont" {
  name                  = "wolkwebblbcont"
  storage_account_name  = azurerm_storage_account.wolkwebappstrg22.name
  container_access_type = "private"
}

resource "azurerm_storage_blob" "applogsblob" {
  name                   = "applogsblob"
  storage_account_name   = azurerm_storage_account.wolkwebappstrg22.name
  storage_container_name = azurerm_storage_container.wolkwebblbcont.name
  type                   = "Block"
}

data "azurerm_container_registry" "acr" {
  name                = "__acrname__"
  resource_group_name = "test"
}


resource "azurerm_kubernetes_cluster" "wolkweb_aks" {
  name                = "__akscluster__"
  location            = azurerm_resource_group.project2_rg.location
  resource_group_name = azurerm_resource_group.project2_rg.name
  dns_prefix          = "wolkwebaks"

  default_node_pool {
    name       = "wolknodepl"
    node_count = 1
    vm_size    = "Standard_DS2_v2"
    enable_auto_scaling = false
  }

  identity {
    type = "SystemAssigned"
  }
}

data "azurerm_user_assigned_identity" "aksmi" {
  name                = "${azurerm_kubernetes_cluster.wolkweb_aks.name}-agentpool"
  resource_group_name = "MC_${azurerm_resource_group.project2_rg.name}_${azurerm_kubernetes_cluster.wolkweb_aks.name}_${azurerm_resource_group.project2_rg.location}"
}

resource "azurerm_role_assignment" "role_Contributor" {
  scope                            = data.azurerm_container_registry.acr.id
  role_definition_name             = "Contributor"
  principal_id                     = data.azurerm_user_assigned_identity.aksmi.principal_id
  skip_service_principal_aad_check = true
}
