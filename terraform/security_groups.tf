# ============================================================
# Security Groups — OpenStack Terraform
# ============================================================

# ---- Web Security Group ----
resource "openstack_networking_secgroup_v2" "web_sg" {
  name        = "terraform-web-sg"
  description = "Security group for web servers — managed by Terraform"
}

# Allow SSH (port 22)
resource "openstack_networking_secgroup_rule_v2" "ssh_ingress" {
  security_group_id = openstack_networking_secgroup_v2.web_sg.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  description       = "Allow SSH access"
}

# Allow HTTP (port 80)
resource "openstack_networking_secgroup_rule_v2" "http_ingress" {
  security_group_id = openstack_networking_secgroup_v2.web_sg.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  description       = "Allow HTTP traffic"
}

# Allow HTTPS (port 443)
resource "openstack_networking_secgroup_rule_v2" "https_ingress" {
  security_group_id = openstack_networking_secgroup_v2.web_sg.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  description       = "Allow HTTPS traffic"
}

# Allow ICMP (ping)
resource "openstack_networking_secgroup_rule_v2" "icmp_ingress" {
  security_group_id = openstack_networking_secgroup_v2.web_sg.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
  description       = "Allow ICMP (ping)"
}

# Allow custom app port (8080)
resource "openstack_networking_secgroup_rule_v2" "app_ingress" {
  security_group_id = openstack_networking_secgroup_v2.web_sg.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8080
  port_range_max    = 8080
  remote_ip_prefix  = "0.0.0.0/0"
  description       = "Allow application traffic on port 8080"
}

# ---- Database Security Group ----
resource "openstack_networking_secgroup_v2" "db_sg" {
  name        = "terraform-db-sg"
  description = "Security group for databases — only internal access"
}

# Allow MySQL/MariaDB from app network only
resource "openstack_networking_secgroup_rule_v2" "mysql_ingress" {
  security_group_id = openstack_networking_secgroup_v2.db_sg.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 3306
  port_range_max    = 3306
  remote_ip_prefix  = var.app_network_cidr
  description       = "Allow MySQL from app network only"
}

# Allow SSH from app network only
resource "openstack_networking_secgroup_rule_v2" "db_ssh_ingress" {
  security_group_id = openstack_networking_secgroup_v2.db_sg.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.app_network_cidr
  description       = "Allow SSH from app network only"
}
