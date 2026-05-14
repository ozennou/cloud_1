resource "azurerm_linux_virtual_machine" "prd-eus-server-01" {
  name                = "prd-eus-server-01"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size

  network_interface_ids = [
    azurerm_network_interface.prd-eus-server-01-nic.id,
  ]

  admin_username                  = var.admin_username
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

resource "azurerm_network_interface" "prd-eus-server-01-nic" {
  name                = "prd-eus-server-01-nic"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.prd-eus-server-01-pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "prd-eus-server-01-nic-nsg-association" {
  network_interface_id      = azurerm_network_interface.prd-eus-server-01-nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}