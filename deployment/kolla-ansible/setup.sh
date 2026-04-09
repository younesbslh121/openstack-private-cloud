#!/bin/bash
# ============================================================
# OpenStack Private Cloud — Kolla-Ansible Automated Setup
# ============================================================
# This script automates the full Kolla-Ansible deployment
# on Debian 12 (Bookworm) — all-in-one setup
#
# Prerequisites:
#   - Debian 12 (fresh install)
#   - 8GB+ RAM, 60GB+ disk, 4+ CPU cores
#   - 2 NICs: eth0 (NAT) + eth1 (Host-Only, no IP)
#   - Internet connectivity
#
# Usage:
#   chmod +x setup.sh
#   ./setup.sh
#
# NOTE: Do NOT run as root. Run as a regular user with sudo.
# ============================================================

set -euo pipefail

# ---- Configuration ----
KOLLA_VENV="$HOME/kolla-venv"
KOLLA_CONFIG="/etc/kolla"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================
# IMPORTANT: Adjust these interface names for YOUR system!
# Run 'ip -brief link show' to find your actual interface names.
#
# On Debian + VirtualBox:
#   - Traditional naming: eth0, eth1
#   - Predictable naming: enp0s3, enp0s8
#
# Change these if your interfaces have different names:
# ============================================================
MANAGEMENT_INTERFACE="eth0"
EXTERNAL_INTERFACE="eth1"
VIP_ADDRESS="192.168.56.250"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "\n${CYAN}========================================${NC}"; echo -e "${CYAN}  STEP: $1${NC}"; echo -e "${CYAN}========================================${NC}\n"; }

# ============================================================
# STEP 0: Pre-flight checks
# ============================================================
log_step "Pre-flight Checks"

if [[ $EUID -eq 0 ]]; then
    log_error "Do NOT run this script as root. Run as a regular user with sudo privileges."
    log_info "Tip: Make sure your user is in the sudo group: sudo usermod -aG sudo \$USER"
    exit 1
fi

# Check OS — Support both Debian and Ubuntu
OS_NAME=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
OS_VERSION=$(grep -oP '(?<=^VERSION_ID=).+' /etc/os-release | tr -d '"')

if [[ "$OS_NAME" == "debian" ]]; then
    log_info "Detected: Debian $OS_VERSION ✓"
    if [[ "${OS_VERSION%%.*}" -lt 11 ]]; then
        log_warn "Debian $OS_VERSION detected. Debian 11+ is recommended for Kolla-Ansible."
    fi
elif [[ "$OS_NAME" == "ubuntu" ]]; then
    log_info "Detected: Ubuntu $OS_VERSION ✓"
else
    log_warn "Detected: $OS_NAME $OS_VERSION — This script is designed for Debian/Ubuntu."
fi

# Check RAM
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
if [[ $TOTAL_RAM -lt 7 ]]; then
    log_error "Insufficient RAM: ${TOTAL_RAM}GB detected. Minimum 8GB required."
    exit 1
fi
log_info "RAM: ${TOTAL_RAM}GB ✓"

# Check disk space
FREE_DISK=$(df -BG / | awk 'NR==2{print $4}' | tr -d 'G')
if [[ $FREE_DISK -lt 40 ]]; then
    log_error "Insufficient disk space: ${FREE_DISK}GB free. Minimum 40GB required."
    exit 1
fi
log_info "Disk: ${FREE_DISK}GB free ✓"

# Auto-detect network interfaces if defaults don't exist
if ! ip link show "$MANAGEMENT_INTERFACE" &>/dev/null; then
    log_warn "Interface '$MANAGEMENT_INTERFACE' not found. Auto-detecting..."
    
    # Try predictable names (VirtualBox)
    if ip link show enp0s3 &>/dev/null; then
        MANAGEMENT_INTERFACE="enp0s3"
        log_info "Auto-detected management interface: enp0s3"
    elif ip link show ens33 &>/dev/null; then
        MANAGEMENT_INTERFACE="ens33"
        log_info "Auto-detected management interface: ens33"
    else
        log_error "Cannot auto-detect management interface!"
        log_info "Available interfaces:"
        ip -brief link show
        log_info "Edit the MANAGEMENT_INTERFACE variable in this script."
        exit 1
    fi
fi
log_info "Management interface: $MANAGEMENT_INTERFACE ✓"

if ! ip link show "$EXTERNAL_INTERFACE" &>/dev/null; then
    log_warn "Interface '$EXTERNAL_INTERFACE' not found. Auto-detecting..."
    
    if ip link show enp0s8 &>/dev/null; then
        EXTERNAL_INTERFACE="enp0s8"
        log_info "Auto-detected external interface: enp0s8"
    elif ip link show ens34 &>/dev/null; then
        EXTERNAL_INTERFACE="ens34"
        log_info "Auto-detected external interface: ens34"
    else
        log_error "Cannot auto-detect external interface!"
        log_info "Available interfaces:"
        ip -brief link show
        log_info "Edit the EXTERNAL_INTERFACE variable in this script."
        exit 1
    fi
fi
log_info "External interface: $EXTERNAL_INTERFACE ✓"

# Update globals.yml with detected interfaces
if [[ -f "$SCRIPT_DIR/globals.yml" ]]; then
    sed -i "s/^network_interface:.*/network_interface: \"$MANAGEMENT_INTERFACE\"/" "$SCRIPT_DIR/globals.yml"
    sed -i "s/^neutron_external_interface:.*/neutron_external_interface: \"$EXTERNAL_INTERFACE\"/" "$SCRIPT_DIR/globals.yml"
    log_info "globals.yml updated with detected interfaces ✓"
fi

# ============================================================
# STEP 1: System Update & Dependencies
# ============================================================
log_step "Installing System Dependencies"

sudo apt-get update
sudo apt-get upgrade -y

# Debian-specific packages
sudo apt-get install -y \
    python3-dev python3-venv python3-pip \
    libffi-dev gcc libssl-dev libdbus-glib-1-dev \
    git curl wget jq \
    bridge-utils net-tools \
    software-properties-common \
    ca-certificates gnupg lsb-release \
    lvm2 thin-provisioning-tools \
    sudo

# Ensure user has sudo access
if ! sudo -l &>/dev/null; then
    log_error "Current user does not have sudo privileges!"
    log_info "Fix: su -c 'usermod -aG sudo $USER' root"
    log_info "Then log out and log back in."
    exit 1
fi

log_info "System dependencies installed ✓"

# ============================================================
# STEP 2: Configure External Interface (No IP)
# ============================================================
log_step "Configuring External Interface"

# Bring up external interface without IP
sudo ip addr flush dev "$EXTERNAL_INTERFACE" 2>/dev/null || true
sudo ip link set "$EXTERNAL_INTERFACE" up

# Debian uses /etc/network/interfaces (NOT netplan)
# Check if the interface is already configured
if ! grep -q "$EXTERNAL_INTERFACE" /etc/network/interfaces 2>/dev/null; then
    # Backup existing config
    sudo cp /etc/network/interfaces /etc/network/interfaces.bak.$(date +%s) 2>/dev/null || true
    
    # Append external interface configuration
    sudo tee -a /etc/network/interfaces > /dev/null <<EOF

# OpenStack external interface (managed by Neutron)
auto ${EXTERNAL_INTERFACE}
iface ${EXTERNAL_INTERFACE} inet manual
    up ip link set \$IFACE up
    down ip link set \$IFACE down
EOF
    
    log_info "External interface added to /etc/network/interfaces ✓"
else
    log_info "External interface already in /etc/network/interfaces ✓"
fi

# Also handle if system uses systemd-networkd
if systemctl is-active systemd-networkd &>/dev/null; then
    sudo tee /etc/systemd/network/99-openstack-external.network > /dev/null <<EOF
[Match]
Name=${EXTERNAL_INTERFACE}

[Network]
DHCP=no
LinkLocalAddressing=no

[Link]
RequiredForOnline=no
EOF
    sudo systemctl restart systemd-networkd 2>/dev/null || true
    log_info "systemd-networkd config created ✓"
fi

log_info "External interface configured (no IP) ✓"

# ============================================================
# STEP 3: Install Docker
# ============================================================
log_step "Installing Docker"

if ! command -v docker &>/dev/null; then
    # Install Docker using official convenience script (works for Debian)
    curl -fsSL https://get.docker.com | sudo bash
    sudo usermod -aG docker "$USER"
    log_info "Docker installed ✓"
    log_warn "You may need to log out and back in for docker group to take effect."
    log_warn "For now, using sudo with docker commands."
else
    log_info "Docker already installed ✓"
fi

sudo systemctl enable docker
sudo systemctl start docker

# Configure Docker daemon for Kolla
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
    "storage-driver": "overlay2",
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    }
}
EOF

sudo systemctl restart docker
log_info "Docker configured ✓"

# Verify Docker is working
if sudo docker info &>/dev/null; then
    log_info "Docker is functional ✓"
else
    log_error "Docker is not working properly!"
    exit 1
fi

# ============================================================
# STEP 4: Create Python Virtual Environment
# ============================================================
log_step "Setting Up Python Virtual Environment"

python3 -m venv "$KOLLA_VENV"
source "$KOLLA_VENV/bin/activate"
pip install -U pip setuptools wheel

log_info "Python venv created at $KOLLA_VENV ✓"

# ============================================================
# STEP 5: Install Kolla-Ansible
# ============================================================
log_step "Installing Kolla-Ansible"

pip install 'ansible-core>=2.16,<2.18'
pip install git+https://opendev.org/openstack/kolla-ansible@master

log_info "Kolla-Ansible installed ✓"

# Install Ansible Galaxy dependencies
kolla-ansible install-deps
log_info "Ansible Galaxy dependencies installed ✓"

# ============================================================
# STEP 6: Configure Kolla-Ansible
# ============================================================
log_step "Configuring Kolla-Ansible"

# Create config directory
sudo mkdir -p "$KOLLA_CONFIG"
sudo chown "$USER:$USER" "$KOLLA_CONFIG"

# Copy default configuration
cp -r "$KOLLA_VENV/share/kolla-ansible/etc_examples/kolla/"* "$KOLLA_CONFIG/"

# Copy our custom globals.yml
if [[ -f "$SCRIPT_DIR/globals.yml" ]]; then
    cp "$SCRIPT_DIR/globals.yml" "$KOLLA_CONFIG/globals.yml"
    log_info "Custom globals.yml copied ✓"
else
    log_warn "No custom globals.yml found, using default"
    # Set minimum required values
    cat >> "$KOLLA_CONFIG/globals.yml" <<EOF

# Auto-configured by setup.sh
kolla_base_distro: "debian"
kolla_install_type: "source"
network_interface: "$MANAGEMENT_INTERFACE"
neutron_external_interface: "$EXTERNAL_INTERFACE"
kolla_internal_vip_address: "$VIP_ADDRESS"
nova_compute_virt_type: "qemu"
enable_cinder: "yes"
enable_cinder_backend_lvm: "yes"
enable_heat: "yes"
neutron_plugin_agent: "openvswitch"
enable_neutron_provider_networks: "yes"
EOF
fi

# Copy inventory
cp "$KOLLA_VENV/share/kolla-ansible/ansible/inventory/all-in-one" "$KOLLA_CONFIG/"

# Generate passwords
kolla-genpwd
log_info "Passwords generated ✓"

log_info "Configuration files at $KOLLA_CONFIG ✓"

# ============================================================
# STEP 7: Prepare Cinder LVM Backend
# ============================================================
log_step "Preparing Cinder LVM Backend"

CINDER_IMG="/var/lib/cinder/cinder-volumes.img"
CINDER_VG="cinder-volumes"

if ! sudo vgs "$CINDER_VG" &>/dev/null; then
    sudo mkdir -p /var/lib/cinder
    
    # Create a 20GB loopback device for Cinder volumes
    log_info "Creating 20GB loopback device for Cinder (this takes a moment)..."
    sudo dd if=/dev/zero of="$CINDER_IMG" bs=1M count=20480 status=progress
    
    # Find free loop device
    LOOP_DEV=$(sudo losetup -f)
    sudo losetup "$LOOP_DEV" "$CINDER_IMG"
    
    # Create physical volume and volume group
    sudo pvcreate "$LOOP_DEV"
    sudo vgcreate "$CINDER_VG" "$LOOP_DEV"
    
    # Create systemd service for loop device persistence across reboots
    sudo tee /etc/systemd/system/cinder-loop.service > /dev/null <<EOF
[Unit]
Description=Setup Cinder LVM Loopback Device
After=local-fs.target
Before=docker.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c '/sbin/losetup \$(/sbin/losetup -f) $CINDER_IMG && /sbin/vgchange -ay $CINDER_VG'
ExecStop=/sbin/vgchange -an $CINDER_VG
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable cinder-loop.service
    
    log_info "Cinder LVM backend created (20GB loopback) ✓"
else
    log_info "Cinder volume group '$CINDER_VG' already exists ✓"
fi

# ============================================================
# STEP 8: Bootstrap Servers
# ============================================================
log_step "Bootstrapping Servers"

kolla-ansible bootstrap-servers -i "$KOLLA_CONFIG/all-in-one"
log_info "Server bootstrap completed ✓"

# ============================================================
# STEP 9: Pre-deployment Checks
# ============================================================
log_step "Running Pre-deployment Checks"

kolla-ansible prechecks -i "$KOLLA_CONFIG/all-in-one"
log_info "Pre-deployment checks passed ✓"

# ============================================================
# STEP 10: Deploy OpenStack
# ============================================================
log_step "Deploying OpenStack (this may take 15-30 minutes)"

kolla-ansible deploy -i "$KOLLA_CONFIG/all-in-one"
log_info "OpenStack deployment completed ✓"

# ============================================================
# STEP 11: Post-Deployment
# ============================================================
log_step "Running Post-Deployment Configuration"

kolla-ansible post-deploy

# Install OpenStack CLI
pip install python-openstackclient python-heatclient python-cinderclient python-neutronclient

log_info "OpenStack CLI tools installed ✓"

# ============================================================
# STEP 12: Summary
# ============================================================
log_step "Deployment Complete! 🎉"

HOST_IP=$(ip -4 addr show "$MANAGEMENT_INTERFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
ADMIN_PASS=$(grep 'keystone_admin_password' "$KOLLA_CONFIG/passwords.yml" | awk '{print $2}')

echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  ☁️  OpenStack Private Cloud — Deployment Summary${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo -e "  ${BLUE}OS:${NC}                 $OS_NAME $OS_VERSION"
echo -e "  ${BLUE}Management NIC:${NC}     $MANAGEMENT_INTERFACE ($HOST_IP)"
echo -e "  ${BLUE}External NIC:${NC}       $EXTERNAL_INTERFACE"
echo ""
echo -e "  ${BLUE}Horizon Dashboard:${NC}  http://${VIP_ADDRESS}"
echo -e "  ${BLUE}Keystone API:${NC}       http://${VIP_ADDRESS}:5000"
echo -e "  ${BLUE}Nova API:${NC}           http://${VIP_ADDRESS}:8774"
echo -e "  ${BLUE}Neutron API:${NC}        http://${VIP_ADDRESS}:9696"
echo -e "  ${BLUE}Glance API:${NC}         http://${VIP_ADDRESS}:9292"
echo -e "  ${BLUE}Cinder API:${NC}         http://${VIP_ADDRESS}:8776"
echo -e "  ${BLUE}Heat API:${NC}           http://${VIP_ADDRESS}:8004"
echo ""
echo -e "  ${YELLOW}Admin Credentials:${NC}"
echo -e "  Username: admin"
echo -e "  Password: $ADMIN_PASS"
echo ""
echo -e "  ${YELLOW}Cloud Configuration:${NC}"
echo -e "  Clouds file: $KOLLA_CONFIG/clouds.yaml"
echo ""
echo -e "  ${CYAN}Next Steps:${NC}"
echo -e "  1. Copy clouds.yaml:"
echo -e "     mkdir -p ~/.config/openstack"
echo -e "     cp $KOLLA_CONFIG/clouds.yaml ~/.config/openstack/"
echo -e "  2. Test: openstack service list"
echo -e "  3. Create demo resources: ./automation/scripts/create-demo-resources.sh"
echo -e "  4. Start monitoring: cd monitoring && docker-compose up -d"
echo ""
echo -e "${GREEN}============================================================${NC}"
