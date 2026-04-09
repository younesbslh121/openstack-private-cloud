#!/bin/bash
# ============================================================
# Create Demo Resources — OpenStack Private Cloud
# ============================================================
# This script creates demo resources to showcase the cloud
# Run after Kolla-Ansible deployment + post-deploy
# ============================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[✓]${NC} $1"; }
log_step()  { echo -e "\n${CYAN}━━━ $1 ━━━${NC}\n"; }
log_warn()  { echo -e "${YELLOW}[!]${NC} $1"; }

# ---- Load credentials ----
if [[ -f /etc/kolla/clouds.yaml ]]; then
    export OS_CLIENT_CONFIG_FILE=/etc/kolla/clouds.yaml
    export OS_CLOUD=kolla-admin
elif [[ -f ~/openrc ]]; then
    source ~/openrc admin admin
else
    echo "ERROR: No credentials found. Run 'kolla-ansible post-deploy' first."
    exit 1
fi

echo -e "${BLUE}"
echo "============================================================"
echo "  ☁️  OpenStack Private Cloud — Demo Resources Creator"
echo "============================================================"
echo -e "${NC}"

# ============================================================
# 1. Upload OS Images
# ============================================================
log_step "1/7 — Uploading OS Images"

# CirrOS (lightweight test image)
if ! openstack image show CirrOS-0.6.2 &>/dev/null; then
    wget -q -O /tmp/cirros.img http://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img
    openstack image create "CirrOS-0.6.2" \
        --file /tmp/cirros.img \
        --disk-format qcow2 \
        --container-format bare \
        --public
    log_info "CirrOS 0.6.2 image uploaded"
    rm -f /tmp/cirros.img
else
    log_info "CirrOS 0.6.2 already exists"
fi

# Ubuntu Cloud Image (optional — larger download)
# if ! openstack image show Ubuntu-24.04 &>/dev/null; then
#     wget -q -O /tmp/ubuntu.img https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
#     openstack image create "Ubuntu-24.04" \
#         --file /tmp/ubuntu.img \
#         --disk-format qcow2 \
#         --container-format bare \
#         --public
#     log_info "Ubuntu 24.04 image uploaded"
# fi

# ============================================================
# 2. Create Flavors
# ============================================================
log_step "2/7 — Creating Compute Flavors"

declare -A FLAVORS=(
    ["m1.nano"]="64 1 1"
    ["m1.tiny"]="512 1 1"
    ["m1.small"]="2048 1 20"
    ["m1.medium"]="4096 2 40"
    ["m1.large"]="8192 4 80"
)

for flavor in "${!FLAVORS[@]}"; do
    read -r ram vcpus disk <<< "${FLAVORS[$flavor]}"
    if ! openstack flavor show "$flavor" &>/dev/null; then
        openstack flavor create "$flavor" \
            --ram "$ram" --vcpus "$vcpus" --disk "$disk" --public
        log_info "Flavor $flavor created (RAM:${ram}MB, vCPU:${vcpus}, Disk:${disk}GB)"
    else
        log_info "Flavor $flavor already exists"
    fi
done

# ============================================================
# 3. Create Networks
# ============================================================
log_step "3/7 — Creating Networks"

# External network
if ! openstack network show external-net &>/dev/null; then
    openstack network create --external \
        --provider-network-type flat \
        --provider-physical-network physnet1 \
        external-net
    
    openstack subnet create external-subnet \
        --network external-net \
        --subnet-range 192.168.56.0/24 \
        --allocation-pool start=192.168.56.200,end=192.168.56.240 \
        --gateway 192.168.56.1 \
        --no-dhcp
    
    log_info "External network created (192.168.56.0/24)"
else
    log_info "External network already exists"
fi

# Internal network
if ! openstack network show internal-net &>/dev/null; then
    openstack network create internal-net
    
    openstack subnet create internal-subnet \
        --network internal-net \
        --subnet-range 10.0.0.0/24 \
        --dns-nameserver 8.8.8.8 \
        --dns-nameserver 8.8.4.4
    
    log_info "Internal network created (10.0.0.0/24)"
else
    log_info "Internal network already exists"
fi

# ============================================================
# 4. Create Router
# ============================================================
log_step "4/7 — Creating Router"

if ! openstack router show main-router &>/dev/null; then
    openstack router create main-router
    openstack router set main-router --external-gateway external-net
    openstack router add subnet main-router internal-subnet
    log_info "Router created and connected (internal → external)"
else
    log_info "Router main-router already exists"
fi

# ============================================================
# 5. Create Security Groups
# ============================================================
log_step "5/7 — Creating Security Groups"

if ! openstack security group show web-sg &>/dev/null; then
    openstack security group create web-sg \
        --description "Allow SSH, HTTP, HTTPS, ICMP"
    
    openstack security group rule create web-sg \
        --protocol tcp --dst-port 22 --remote-ip 0.0.0.0/0
    openstack security group rule create web-sg \
        --protocol tcp --dst-port 80 --remote-ip 0.0.0.0/0
    openstack security group rule create web-sg \
        --protocol tcp --dst-port 443 --remote-ip 0.0.0.0/0
    openstack security group rule create web-sg \
        --protocol icmp --remote-ip 0.0.0.0/0
    
    log_info "Security group 'web-sg' created (SSH, HTTP, HTTPS, ICMP)"
else
    log_info "Security group 'web-sg' already exists"
fi

# ============================================================
# 6. Create SSH Keypair
# ============================================================
log_step "6/7 — Creating SSH Keypair"

if ! openstack keypair show default-keypair &>/dev/null; then
    if [[ ! -f ~/.ssh/openstack-key ]]; then
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/openstack-key -N "" -q
    fi
    openstack keypair create --public-key ~/.ssh/openstack-key.pub default-keypair
    log_info "Keypair 'default-keypair' created"
else
    log_info "Keypair 'default-keypair' already exists"
fi

# ============================================================
# 7. Launch Demo Instance
# ============================================================
log_step "7/7 — Launching Demo Instance"

if ! openstack server show demo-instance &>/dev/null; then
    openstack server create \
        --image CirrOS-0.6.2 \
        --flavor m1.tiny \
        --network internal-net \
        --security-group web-sg \
        --key-name default-keypair \
        --wait \
        demo-instance
    
    # Create and attach floating IP
    FIP=$(openstack floating ip create external-net -f value -c floating_ip_address)
    openstack server add floating ip demo-instance "$FIP"
    
    log_info "Demo instance created with floating IP: $FIP"
else
    log_info "Demo instance already exists"
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  ☁️  Demo Resources Created Successfully!${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""
echo -e "${CYAN}Images:${NC}"
openstack image list -f table
echo ""
echo -e "${CYAN}Flavors:${NC}"
openstack flavor list -f table
echo ""
echo -e "${CYAN}Networks:${NC}"
openstack network list -f table
echo ""
echo -e "${CYAN}Routers:${NC}"
openstack router list -f table
echo ""
echo -e "${CYAN}Instances:${NC}"
openstack server list -f table
echo ""
echo -e "${CYAN}Floating IPs:${NC}"
openstack floating ip list -f table
echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  All demo resources created! Access Horizon at:${NC}"
echo -e "${GREEN}  http://192.168.56.250${NC}"
echo -e "${GREEN}============================================================${NC}"
