# ============================================================
# Variables — OpenStack Terraform Provider
# ============================================================

# ---- Provider Variables ----
variable "auth_url" {
  description = "OpenStack Keystone authentication URL"
  type        = string
  default     = "http://192.168.56.250:5000/v3"
}

variable "tenant_name" {
  description = "OpenStack project/tenant name"
  type        = string
  default     = "demo"
}

variable "user_name" {
  description = "OpenStack username"
  type        = string
  default     = "demo"
}

variable "password" {
  description = "OpenStack password"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "OpenStack region"
  type        = string
  default     = "RegionOne"
}

# ---- Network Variables ----
variable "external_network_name" {
  description = "Name of the external/provider network"
  type        = string
  default     = "external-net"
}

variable "app_network_cidr" {
  description = "CIDR for application network"
  type        = string
  default     = "10.10.0.0/24"
}

variable "dns_nameservers" {
  description = "DNS nameservers for subnets"
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}

# ---- Compute Variables ----
variable "image_name" {
  description = "Name of the OS image to use"
  type        = string
  default     = "CirrOS-0.6.2"
}

variable "flavor_name" {
  description = "Name of the compute flavor"
  type        = string
  default     = "m1.small"
}

variable "keypair_name" {
  description = "Name of the SSH keypair"
  type        = string
  default     = "default-keypair"
}

variable "instance_count" {
  description = "Number of web server instances to create"
  type        = number
  default     = 2
}

# ---- Tags ----
variable "environment" {
  description = "Environment tag"
  type        = string
  default     = "production"
}

variable "project" {
  description = "Project name tag"
  type        = string
  default     = "openstack-private-cloud"
}
