resource "azurerm_linux_virtual_machine" "vm" {
  count               = var.vm_count
  name                = "vm-${var.project_name}-${count.index == 0 ? "cp" : format("worker%02d", count.index)}-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.vm[count.index].id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    name                 = "osdisk-${var.project_name}-vm${count.index}-${var.environment}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  computer_name                   = count.index == 0 ? "k8s-control-plane" : "k8s-worker-${count.index}"
  disable_password_authentication = true

  tags = merge(var.tags, {
    Name = count.index == 0 ? "control-plane" : "worker-${count.index}"
    Role = count.index == 0 ? "control-plane" : "worker"
  })
}
