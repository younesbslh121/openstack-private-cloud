# ============================================================
# Network Resources — OpenStack Terraform
# ============================================================
# Creates: App network + subnet + router + floating IPs
# ============================================================

# ---- Data Sources ----
data "openstack_networking_network_v2" "external" {
  name = var.external_network_name
}

# ---- Application Network ----
resource "openstack_networking_network_v2" "app_network" {
  name           = "app-network"
  admin_state_up = true

  tags = [var.environment, var.project]
}

resource "openstack_networking_subnet_v2" "app_subnet" {
  name            = "app-subnet"
  network_id      = openstack_networking_network_v2.app_network.id
  cidr            = var.app_network_cidr
  ip_version      = 4
  dns_nameservers = var.dns_nameservers

  allocation_pool {
    start = cidrhost(var.app_network_cidr, 10)
    end   = cidrhost(var.app_network_cidr, 200)
  }

  tags = [var.environment]
}

# ---- Router ----
resource "openstack_networking_router_v2" "app_router" {
  name                = "app-router"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.external.id

  tags = [var.environment, var.project]
}

resource "openstack_networking_router_interface_v2" "app_router_interface" {
  router_id = openstack_networking_router_v2.app_router.id
  subnet_id = openstack_networking_subnet_v2.app_subnet.id
}

# ---- Floating IPs ----
resource "openstack_networking_floatingip_v2" "web_fips" {
  count = var.instance_count
  pool  = var.external_network_name

  tags = [var.environment, "web-server-${count.index + 1}"]
}
