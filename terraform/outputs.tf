# ============================================================
# Outputs — OpenStack Terraform
# ============================================================

output "app_network_id" {
  description = "ID of the application network"
  value       = openstack_networking_network_v2.app_network.id
}

output "app_subnet_id" {
  description = "ID of the application subnet"
  value       = openstack_networking_subnet_v2.app_subnet.id
}

output "router_id" {
  description = "ID of the application router"
  value       = openstack_networking_router_v2.app_router.id
}

output "web_server_ids" {
  description = "IDs of the web server instances"
  value       = openstack_compute_instance_v2.web_servers[*].id
}

output "web_server_private_ips" {
  description = "Private IPs of the web server instances"
  value       = openstack_compute_instance_v2.web_servers[*].access_ip_v4
}

output "web_server_floating_ips" {
  description = "Floating IPs assigned to web servers"
  value       = openstack_networking_floatingip_v2.web_fips[*].address
}

output "web_security_group_id" {
  description = "ID of the web security group"
  value       = openstack_networking_secgroup_v2.web_sg.id
}

output "data_volume_id" {
  description = "ID of the data volume"
  value       = openstack_blockstorage_volume_v3.data_volume.id
}

output "access_urls" {
  description = "URLs to access the web servers"
  value       = [for ip in openstack_networking_floatingip_v2.web_fips[*].address : "http://${ip}"]
}
