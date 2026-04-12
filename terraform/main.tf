# ============================================================
# OpenStack Private Cloud — Terraform Configuration
# ============================================================
# Main provider configuration for OpenStack
# ============================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54"
    }
  }

  # Optional: Remote backend for state management
  # backend "swift" {
  #   container         = "terraform-state"
  #   archive_container = "terraform-state-archive"
  #   cloud             = "openstack"
  # }
}

# ============================================================
# Provider Configuration
# ============================================================

provider "openstack" {
  auth_url            = var.auth_url
  tenant_name         = var.tenant_name
  user_name           = var.user_name
  password            = var.password
  region              = var.region
  user_domain_name    = "Default"
  project_domain_name = "Default"

  # Alternatively, use clouds.yaml:
  # cloud = "openstack"
}
