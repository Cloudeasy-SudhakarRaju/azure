/*
* Demonstrate use of provisioner 'remote-exec' to execute a command
* on a new VM instance.
*/

/*
* NOTE: It is very poor practice to hardcode sensitive information
* such as user name, password, etc. Hardcoded values are used here
* only to simplify the tutorial.
*/
variable "admin_username" {
  default = "sudhakar"
}

variable "admin_password" {
  default = "Password1234!"
}

variable "resource_prefix" {
  default = "sudha-rg"
}

# You'll usually want to set this to a region near you.
variable "location" {
  default = "eastus2"
}

# Configure the provider.
provider "azurerm" {
  subscription_id= "b9e44674-9ff1-4d05-9e98-23af627f19f5"
  client_id= "b5b781cd-e4e7-43f5-b0e2-c7ae7d8310e0"
  client_secret= "6UxWi1:[5h0mVJXYp:Bo.n_xAryh/vG4"
  tenant_id= "d3bc2180-cb1e-40f7-b59a-154105743342"
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "${var.resource_prefix}TFResourceGroup"
  location = var.location
}

# Create virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.resource_prefix}TFVnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create subnet
resource "azurerm_subnet" "subnet" {
  name                 = "${var.resource_prefix}TFSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefix       = "10.0.1.0/24"
}

# Create public IP
resource "azurerm_public_ip" "publicip" {
  name                         = "${var.resource_prefix}TFPublicIP"
  location                     = var.location
  resource_group_name          = azurerm_resource_group.rg.name
  allocation_method = "Static"
  }


data "azurerm_public_ip" "publicip" {
  name                = azurerm_public_ip.publicip.name
  resource_group_name = azurerm_resource_group.rg.name
}


# Create Network Security Group and rule
resource "azurerm_network_security_group" "nsg" {
  name                = "${var.resource_prefix}TFNSG"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}


# Create network interface
resource "azurerm_network_interface" "nic" {
  name                      = "${var.resource_prefix}NIC"
  location                  = var.location
  resource_group_name       = azurerm_resource_group.rg.name
  network_security_group_id = azurerm_network_security_group.nsg.id

  ip_configuration {
    name                          = "${var.resource_prefix}NICConfg"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = azurerm_public_ip.publicip.id
  }
}

# Create a Linux virtual machine
resource "azurerm_virtual_machine" "vm" {
  name                  = "${var.resource_prefix}TFVM"
  location              = var.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  vm_size               = "Standard_DS1_v2"

  storage_os_disk {
    name              = "${var.resource_prefix}OsDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04.0-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = "${var.resource_prefix}TFVM"
    admin_username = var.admin_username
    admin_password = var.admin_password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  provisioner "local-exec" {
    command = "echo ${azurerm_network_interface.nic.private_ip_address} >> privateip.txt"
  }
}

