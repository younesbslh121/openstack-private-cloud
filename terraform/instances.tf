# ============================================================
# Compute Instances — OpenStack Terraform
# ============================================================

# ---- Data Sources ----
data "openstack_images_image_v2" "os_image" {
  name        = var.image_name
  most_recent = true
}

# ---- Cloud-Init User Data ----
data "template_file" "web_init" {
  template = <<-EOT
    #!/bin/bash
    echo "============================================"
    echo "  OpenStack Private Cloud — Web Server Init"
    echo "============================================"
    
    # Update system
    apt-get update -y 2>/dev/null || yum update -y 2>/dev/null
    
    # Install Nginx (if Ubuntu/Debian available)
    if command -v apt-get &>/dev/null; then
      apt-get install -y nginx
    fi
    
    # Create a custom landing page
    HOSTNAME=$(hostname)
    IP=$(hostname -I | awk '{print $1}')
    
    cat > /var/www/html/index.html 2>/dev/null << 'HTMLEOF'
    <!DOCTYPE html>
    <html>
    <head>
      <title>OpenStack Private Cloud — INPT</title>
      <style>
        body {
          font-family: 'Segoe UI', sans-serif;
          background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
          color: #fff;
          display: flex;
          justify-content: center;
          align-items: center;
          min-height: 100vh;
          margin: 0;
        }
        .container {
          text-align: center;
          background: rgba(255,255,255,0.1);
          backdrop-filter: blur(10px);
          border-radius: 20px;
          padding: 40px 60px;
          border: 1px solid rgba(255,255,255,0.2);
        }
        h1 { font-size: 2.5em; margin-bottom: 10px; }
        .badge {
          display: inline-block;
          background: #e94560;
          padding: 5px 15px;
          border-radius: 20px;
          font-size: 0.9em;
          margin: 5px;
        }
        .info { color: #a8a8a8; margin-top: 20px; font-size: 0.9em; }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>☁️ OpenStack Private Cloud</h1>
        <p>Deployed via <span class="badge">Kolla-Ansible</span> <span class="badge">Terraform</span></p>
        <p class="info">Instance provisioned by Terraform on OpenStack</p>
        <p class="info">INPT — 2ème Année Cycle Ingénieur</p>
      </div>
    </body>
    </html>
    HTMLEOF
    
    # Start web server
    systemctl enable nginx 2>/dev/null && systemctl restart nginx 2>/dev/null
    
    echo "Web server initialization complete!"
  EOT
}

# ---- Web Server Instances ----
resource "openstack_compute_instance_v2" "web_servers" {
  count           = var.instance_count
  name            = "web-server-${format("%02d", count.index + 1)}"
  image_id        = data.openstack_images_image_v2.os_image.id
  flavor_name     = var.flavor_name
  key_pair        = var.keypair_name
  security_groups = [openstack_networking_secgroup_v2.web_sg.name]
  user_data       = data.template_file.web_init.rendered

  network {
    uuid = openstack_networking_network_v2.app_network.id
  }

  metadata = {
    environment = var.environment
    project     = var.project
    role        = "web-server"
    managed_by  = "terraform"
  }

  tags = [var.environment, var.project, "web-server"]

  depends_on = [
    openstack_networking_router_interface_v2.app_router_interface
  ]
}

# ---- Floating IP Associations ----
resource "openstack_compute_floatingip_associate_v2" "web_fip_assoc" {
  count       = var.instance_count
  floating_ip = openstack_networking_floatingip_v2.web_fips[count.index].address
  instance_id = openstack_compute_instance_v2.web_servers[count.index].id
}

# ---- Block Storage Volume ----
resource "openstack_blockstorage_volume_v3" "data_volume" {
  name        = "web-data-volume"
  size        = 10
  description = "Persistent data volume for web servers"

  metadata = {
    managed_by = "terraform"
    purpose    = "web-data"
  }
}

resource "openstack_compute_volume_attach_v2" "data_vol_attach" {
  instance_id = openstack_compute_instance_v2.web_servers[0].id
  volume_id   = openstack_blockstorage_volume_v3.data_volume.id
}
