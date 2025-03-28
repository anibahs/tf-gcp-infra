provider "azurerm" {
  features {}
}

# Variables
variable "resource_group_name" {}
variable "location" {}
variable "vmss_name" {}
variable "sql_server_name" {}
variable "sql_database_name" {}
variable "admin_username" {}
variable "admin_password" {}
variable "app_service_plan_name" {}
variable "app_service_name" {}
variable "service_bus_namespace" {}
variable "service_bus_queue" {}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

# Virtual Machine Scale Set
resource "azurerm_virtual_machine_scale_set" "main" {
  name                = var.vmss_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku {
    name     = "Standard_DS1_v2"
    tier     = "Standard"
    capacity = 2
  }
  upgrade_policy {
    mode = "Automatic"
  }

  # Network configuration
  network_profile {
    name    = "networkProfile"
    primary = true

    ip_configuration {
      name      = "ipconfig"
      primary   = true
      subnet_id = azurerm_subnet.main.id
    }
  }

  # OS Profile
  os_profile {
    computer_name_prefix = "vmss"
    admin_username       = var.admin_username
    admin_password       = var.admin_password
  }

  # Image configuration
  storage_profile {
    image_reference {
      publisher = "Canonical"
      offer     = "UbuntuServer"
      sku       = "18.04-LTS"
      version   = "latest"
    }
  }
}

# Subnet for VMSS
resource "azurerm_virtual_network" "main" {
  name                = "myVnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "main" {
  name                 = "mySubnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Azure SQL Server
resource "azurerm_sql_server" "main" {
  name                         = var.sql_server_name
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = var.admin_username
  administrator_login_password = var.admin_password
}

# Azure SQL Database
resource "azurerm_sql_database" "main" {
  name                = var.sql_database_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  server_name         = azurerm_sql_server.main.name
  requested_service_objective_name = "S0"
}

# Azure Service Bus Namespace
resource "azurerm_servicebus_namespace" "main" {
  name                = var.service_bus_namespace
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku {
    name     = "Standard"
    tier     = "Standard"
  }
}

# Azure Service Bus Queue
resource "azurerm_servicebus_queue" "main" {
  name                = var.service_bus_queue
  resource_group_name = azurerm_resource_group.main.name
  namespace_name      = azurerm_servicebus_namespace.main.name
}

# Output
output "sql_server_fqdn" {
  value = azurerm_sql_server.main.fully_qualified_domain_name
}

output "service_bus_namespace" {
  value = azurerm_servicebus_namespace.main.name
}
