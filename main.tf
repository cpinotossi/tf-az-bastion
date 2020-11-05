# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 2.26"
    }
  }
}

provider "azurerm" {
  features {}
}

# Define Resource Group
resource "azurerm_resource_group" "networkRG" {
  name     = "bastion-rg"
  location = "West Europe"
}

resource "azurerm_virtual_network" "ams01VNet" {
  name                = "ams-01-vnet"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.networkRG.location
  resource_group_name = azurerm_resource_group.networkRG.name
}

resource "azurerm_subnet" "ams01BastionSubnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.networkRG.name
  virtual_network_name = azurerm_virtual_network.ams01VNet.name
  address_prefixes     = ["10.1.0.0/27"]
}

resource "azurerm_bastion_host" "ams01Bastion" {
  name                = "ams-01-bastion"
  location            = azurerm_resource_group.networkRG.location
  resource_group_name = azurerm_resource_group.networkRG.name

  ip_configuration {
    name                 = "ams-01-bastion-ipc"
    subnet_id            = azurerm_subnet.ams01BastionSubnet.id
    public_ip_address_id = azurerm_public_ip.ams01BastionPIP.id
  }
}

resource "azurerm_public_ip" "ams01BastionPIP" {
  name                = "ams-01-bastion-ip"
  location            = azurerm_resource_group.networkRG.location
  resource_group_name = azurerm_resource_group.networkRG.name
  allocation_method   = "Static"
  sku                 = "Standard"
}


resource "azurerm_virtual_network" "ams02VNet" {
  name                = "ams-02-vnet"
  address_space       = ["10.2.0.0/16"]
  location            = azurerm_resource_group.networkRG.location
  resource_group_name = azurerm_resource_group.networkRG.name
}

resource "azurerm_subnet" "ams02WorkloadSubnet" {
  name                 = "ams-02-worlkload-subnet"
  resource_group_name  = azurerm_resource_group.networkRG.name
  virtual_network_name = azurerm_virtual_network.ams02VNet.name
  address_prefixes     = ["10.2.0.64/27"]
}

resource "azurerm_network_interface" "ams01Nic" {
  name                = "ams-01-nic"
  location            = azurerm_resource_group.networkRG.location
  resource_group_name = azurerm_resource_group.networkRG.name

  ip_configuration {
    name                          = "ams-vm-linux-01-ipc"
    subnet_id                     = azurerm_subnet.ams02WorkloadSubnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost("10.2.0.64/27", 5)
  }
}

resource "azurerm_linux_virtual_machine" "amsLinux01VM" {
  name                            = "lin-01-vm"
  location                        = azurerm_resource_group.networkRG.location
  resource_group_name             = azurerm_resource_group.networkRG.name
  size                            = "Standard_F2"
  disable_password_authentication = false
  admin_username                  = "chpinoto"
  admin_password                  = "demo!pass123"
  network_interface_ids = [
    azurerm_network_interface.ams01Nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
}


resource "azurerm_virtual_network_peering" "ams01Peering" {
  name                      = "peer1to2"
  resource_group_name       = azurerm_resource_group.networkRG.name
  virtual_network_name      = azurerm_virtual_network.ams01VNet.name
  remote_virtual_network_id = azurerm_virtual_network.ams02VNet.id
}

resource "azurerm_virtual_network_peering" "ams02Peering" {
  name                      = "peer2to1"
  resource_group_name       = azurerm_resource_group.networkRG.name
  virtual_network_name      = azurerm_virtual_network.ams02VNet.name
  remote_virtual_network_id = azurerm_virtual_network.ams01VNet.id
}


