terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "2.57.0"
    }
  }
}

provider "azurerm" {
  features {}
}

locals {

    common = {
        location    = "koreacentral"
        name        = "kafka-syslog-demo"
    }
    
    vm = {
        kafka = { 
            size            = "Standard_B2s"
            admin_username  = "azureuser"
            admin_password  = "cisco!123"
            source_image_reference = {
                publisher = "Canonical"
                offer     = "UbuntuServer"
                sku       = "18.04-LTS"
                version   = "latest"
            }
        }
        # receiver = { 
        #     size            = "Standard_B1s"
        #     admin_username  = "azureuser"
        #     admin_password  = "cisco!123"
        #     source_image_reference = {
        #         publisher = "Canonical"
        #         offer     = "UbuntuServer"
        #         sku       = "18.04-LTS"
        #         version   = "latest"
        #     }
        # }
    }

    pubilc_ip = {
        kafka       = {}
        # receiver    = {}
    }

    nsg = {
        kafka-nsg       = {}
        # receiver-nsg    = {}
    }
}

data "template_file" "user_data" {
    template = file("./cloud-init")
}

resource "azurerm_resource_group" "rg" {
    name        = format("%s-rg", local.common.name)
    location    = local.common.location
}

resource "azurerm_virtual_network" "vnet" {
    name                = format("%s-vnet", local.common.name)
    resource_group_name = azurerm_resource_group.rg.name
    location            = azurerm_resource_group.rg.location
    address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
    name                 = "default"
    virtual_network_name = azurerm_virtual_network.vnet.name
    resource_group_name  = azurerm_resource_group.rg.name
    address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_linux_virtual_machine" "vm" {
    for_each                = local.vm
    name                    = format("%s-vm", each.key)
    resource_group_name     = azurerm_resource_group.rg.name
    location                = azurerm_resource_group.rg.location
    size                    = each.value.size
    admin_username          = each.value.admin_username
    network_interface_ids   = [ contains(keys(azurerm_network_interface.nic), each.key) ? azurerm_network_interface.nic[each.key].id : null ]

    admin_password          = each.value.admin_password
    disable_password_authentication = false

    os_disk {
        caching              = "ReadWrite"
        storage_account_type = "Standard_LRS"
    }

    source_image_reference {
        publisher = each.value.source_image_reference.publisher
        offer     = each.value.source_image_reference.offer
        sku       = each.value.source_image_reference.sku
        version   = each.value.source_image_reference.version
    }

    # custom_data = contains(keys(each.value), "cloud-init") ? base64encode(each.value.cloud-init) : null
    custom_data = base64encode(data.template_file.user_data.rendered)
}

resource "azurerm_network_interface" "nic" {
    for_each            = local.vm
    name                = format("%s-nic", each.key)
    location            = azurerm_resource_group.rg.location 
    resource_group_name = azurerm_resource_group.rg.name

    ip_configuration {
        name                            = "internal"
        subnet_id                       = azurerm_subnet.subnet.id
        private_ip_address_allocation   = "Dynamic"
        public_ip_address_id            = contains(keys(azurerm_public_ip.pip), each.key) ? azurerm_public_ip.pip[each.key].id : null
    }
}

resource "azurerm_public_ip" "pip" {
    for_each            = local.pubilc_ip
    name                = format("%s-pip", each.key)
    resource_group_name = azurerm_resource_group.rg.name
    location            = azurerm_resource_group.rg.location
    allocation_method   = "Dynamic"
}

resource "azurerm_network_security_group" "nsg" {
    for_each            = local.vm
    name                = format("%s-nsg", each.key)
    location            = azurerm_resource_group.rg.location 
    resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_interface_security_group_association" "nsg_association" {
    for_each                    = local.vm
    network_interface_id        = azurerm_network_interface.nic[each.key].id
    network_security_group_id   = azurerm_network_security_group.nsg[each.key].id
}

resource "azurerm_network_security_rule" "nsg_rule_9092" {
    depends_on                  = [azurerm_network_security_group.nsg]
    for_each                    = local.nsg
    name                        = "any_9092"
    priority                    = 100
    direction                   = "Inbound"
    access                      = "Allow"
    protocol                    = "*"
    source_port_range           = "*"
    destination_port_range      = "9092"
    source_address_prefix       = "*"
    destination_address_prefix  = "*"
    resource_group_name         = azurerm_resource_group.rg.name
    network_security_group_name = each.key
}

resource "azurerm_network_security_rule" "nsg_rule_ssh" {
    depends_on                  = [azurerm_network_security_group.nsg]
    for_each                    = local.nsg
    name                        = "ssh"
    priority                    = 200
    direction                   = "Inbound"
    access                      = "Allow"
    protocol                    = "Tcp"
    source_port_range           = "*"
    destination_port_range      = "22"
    source_address_prefix       = "*"
    destination_address_prefix  = "*"
    resource_group_name         = azurerm_resource_group.rg.name
    network_security_group_name = each.key
}