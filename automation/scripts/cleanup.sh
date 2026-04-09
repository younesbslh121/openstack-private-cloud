#!/bin/bash
# ============================================================
# Cleanup Script — OpenStack Private Cloud
# ============================================================
# Removes all demo resources (instances, networks, images, etc.)
# ============================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }

# ---- Load credentials ----
if [[ -f /etc/kolla/clouds.yaml ]]; then
    export OS_CLIENT_CONFIG_FILE=/etc/kolla/clouds.yaml
    export OS_CLOUD=kolla-admin
elif [[ -f ~/openrc ]]; then
    source ~/openrc admin admin
fi

echo -e "${RED}"
echo "============================================================"
echo "  ⚠️  OpenStack Cleanup — This will DELETE all resources!"
echo "============================================================"
echo -e "${NC}"

read -p "Are you sure you want to continue? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo "Aborted."
    exit 0
fi

# 1. Delete instances
echo ""
echo "Deleting instances..."
for server in $(openstack server list --all-projects -f value -c ID 2>/dev/null); do
    openstack server delete "$server" --wait 2>/dev/null && log_info "Deleted instance $server" || true
done

# 2. Delete floating IPs
echo "Deleting floating IPs..."
for fip in $(openstack floating ip list -f value -c ID 2>/dev/null); do
    openstack floating ip delete "$fip" 2>/dev/null && log_info "Deleted floating IP $fip" || true
done

# 3. Delete routers
echo "Deleting routers..."
for router in $(openstack router list -f value -c ID 2>/dev/null); do
    # Remove interfaces first
    for subnet in $(openstack router show "$router" -f json | jq -r '.interfaces_info[]?.subnet_id // empty' 2>/dev/null); do
        openstack router remove subnet "$router" "$subnet" 2>/dev/null || true
    done
    openstack router unset --external-gateway "$router" 2>/dev/null || true
    openstack router delete "$router" 2>/dev/null && log_info "Deleted router $router" || true
done

# 4. Delete networks (non-external)
echo "Deleting networks..."
for net in $(openstack network list --internal -f value -c ID 2>/dev/null); do
    # Delete ports first
    for port in $(openstack port list --network "$net" -f value -c ID 2>/dev/null); do
        openstack port delete "$port" 2>/dev/null || true
    done
    openstack network delete "$net" 2>/dev/null && log_info "Deleted network $net" || true
done

# 5. Delete external network
for net in $(openstack network list --external -f value -c ID 2>/dev/null); do
    openstack network delete "$net" 2>/dev/null && log_info "Deleted external network $net" || true
done

# 6. Delete volumes
echo "Deleting volumes..."
for vol in $(openstack volume list --all-projects -f value -c ID 2>/dev/null); do
    openstack volume delete "$vol" --force 2>/dev/null && log_info "Deleted volume $vol" || true
done

# 7. Delete security groups (except default)
echo "Deleting security groups..."
for sg in $(openstack security group list -f value -c ID -c Name 2>/dev/null | grep -v default | awk '{print $1}'); do
    openstack security group delete "$sg" 2>/dev/null && log_info "Deleted security group $sg" || true
done

# 8. Delete keypairs
echo "Deleting keypairs..."
for kp in $(openstack keypair list -f value -c Name 2>/dev/null); do
    openstack keypair delete "$kp" 2>/dev/null && log_info "Deleted keypair $kp" || true
done

# 9. Delete images
echo "Deleting images..."
for img in $(openstack image list -f value -c ID 2>/dev/null); do
    openstack image delete "$img" 2>/dev/null && log_info "Deleted image $img" || true
done

# 10. Delete Heat stacks
echo "Deleting Heat stacks..."
for stack in $(openstack stack list -f value -c ID 2>/dev/null); do
    openstack stack delete "$stack" --yes --wait 2>/dev/null && log_info "Deleted stack $stack" || true
done

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  Cleanup complete! All resources removed.${NC}"
echo -e "${GREEN}============================================================${NC}"
