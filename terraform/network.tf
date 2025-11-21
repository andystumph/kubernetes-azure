resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.project_name}-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = var.vnet_address_space

  tags = var.tags
}

resource "azurerm_subnet" "main" {
  name                 = "snet-${var.project_name}-${var.environment}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_address_prefix]
}

resource "azurerm_public_ip" "vm" {
  count               = var.vm_count
  name                = "pip-${var.project_name}-vm${count.index}-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = merge(var.tags, {
    Name = count.index == 0 ? "control-plane" : "worker-${count.index}"
  })
}

resource "azurerm_network_interface" "vm" {
  count               = var.vm_count
  name                = "nic-${var.project_name}-vm${count.index}-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm[count.index].id
  }

  tags = var.tags
}

resource "azurerm_network_interface_security_group_association" "vm" {
  count                     = var.vm_count
  network_interface_id      = azurerm_network_interface.vm[count.index].id
  network_security_group_id = count.index == 0 ? azurerm_network_security_group.control_plane.id : azurerm_network_security_group.worker.id
}

# Associate NSG with subnet for CKV2_AZURE_31 compliance
resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.control_plane.id
}
