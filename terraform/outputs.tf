output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "control_plane_public_ip" {
  description = "Public IP of the control plane node"
  value       = azurerm_public_ip.vm[0].ip_address
}

output "control_plane_private_ip" {
  description = "Private IP of the control plane node"
  value       = azurerm_network_interface.vm[0].private_ip_address
}

output "worker_public_ips" {
  description = "Public IPs of worker nodes"
  value       = [for i in range(1, var.vm_count) : azurerm_public_ip.vm[i].ip_address]
}

output "worker_private_ips" {
  description = "Private IPs of worker nodes"
  value       = [for i in range(1, var.vm_count) : azurerm_network_interface.vm[i].private_ip_address]
}

output "all_vm_names" {
  description = "Names of all VMs"
  value       = azurerm_linux_virtual_machine.vm[*].name
}

output "ssh_command_control_plane" {
  description = "SSH command for control plane node"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.vm[0].ip_address}"
}

output "k8s_api_endpoint" {
  description = "Kubernetes API endpoint"
  value       = "https://${azurerm_public_ip.vm[0].ip_address}:6443"
}
