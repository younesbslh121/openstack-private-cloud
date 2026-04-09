#!/bin/bash
# ============================================================
# Health Check — OpenStack Private Cloud
# ============================================================
# Verifies all OpenStack services are running correctly
# ============================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

check_pass() { ((PASS++)); echo -e "  ${GREEN}✓ PASS${NC} — $1"; }
check_fail() { ((FAIL++)); echo -e "  ${RED}✗ FAIL${NC} — $1"; }
check_warn() { ((WARN++)); echo -e "  ${YELLOW}⚠ WARN${NC} — $1"; }

# ---- Load credentials ----
if [[ -f /etc/kolla/clouds.yaml ]]; then
    export OS_CLIENT_CONFIG_FILE=/etc/kolla/clouds.yaml
    export OS_CLOUD=kolla-admin
elif [[ -f ~/openrc ]]; then
    source ~/openrc admin admin
fi

echo -e "${BLUE}"
echo "============================================================"
echo "  ☁️  OpenStack Private Cloud — Health Check"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================================"
echo -e "${NC}"

# ============================================================
# 1. Docker Containers
# ============================================================
echo -e "${CYAN}━━━ Docker Containers ━━━${NC}"

TOTAL_CONTAINERS=$(docker ps --format '{{.Names}}' | wc -l)
RUNNING_CONTAINERS=$(docker ps --filter "status=running" --format '{{.Names}}' | wc -l)
EXITED_CONTAINERS=$(docker ps -a --filter "status=exited" --format '{{.Names}}' | wc -l)

if [[ $RUNNING_CONTAINERS -gt 0 ]]; then
    check_pass "Docker: $RUNNING_CONTAINERS containers running"
else
    check_fail "Docker: No containers running"
fi

if [[ $EXITED_CONTAINERS -gt 0 ]]; then
    check_warn "Docker: $EXITED_CONTAINERS containers exited"
    docker ps -a --filter "status=exited" --format '    → {{.Names}} ({{.Status}})'
fi

# ============================================================
# 2. OpenStack Services
# ============================================================
echo ""
echo -e "${CYAN}━━━ OpenStack Services ━━━${NC}"

SERVICES=("keystone" "nova" "neutron" "glance" "cinder" "heat" "placement")

for svc in "${SERVICES[@]}"; do
    if docker ps --format '{{.Names}}' | grep -q "$svc"; then
        check_pass "$svc — container running"
    else
        check_fail "$svc — container NOT found"
    fi
done

# ============================================================
# 3. API Endpoints
# ============================================================
echo ""
echo -e "${CYAN}━━━ API Endpoints ━━━${NC}"

VIP="192.168.56.250"

declare -A ENDPOINTS=(
    ["Keystone"]="$VIP:5000/v3"
    ["Nova"]="$VIP:8774/v2.1"
    ["Neutron"]="$VIP:9696"
    ["Glance"]="$VIP:9292/v2/images"
    ["Cinder"]="$VIP:8776/v3"
    ["Heat"]="$VIP:8004/v1"
    ["Placement"]="$VIP:8778"
    ["Horizon"]="$VIP:80"
)

for name in "${!ENDPOINTS[@]}"; do
    url="${ENDPOINTS[$name]}"
    if curl -sf -o /dev/null -w '' --connect-timeout 5 "http://$url" 2>/dev/null; then
        check_pass "$name API — http://$url"
    else
        check_fail "$name API — http://$url (unreachable)"
    fi
done

# ============================================================
# 4. OpenStack CLI Checks
# ============================================================
echo ""
echo -e "${CYAN}━━━ OpenStack CLI Checks ━━━${NC}"

# Service list
if openstack service list &>/dev/null; then
    SERVICE_COUNT=$(openstack service list -f value | wc -l)
    check_pass "Service catalog: $SERVICE_COUNT services registered"
else
    check_fail "Cannot query service catalog"
fi

# Endpoint list
if openstack endpoint list &>/dev/null; then
    ENDPOINT_COUNT=$(openstack endpoint list -f value | wc -l)
    check_pass "Endpoints: $ENDPOINT_COUNT endpoints configured"
else
    check_fail "Cannot query endpoints"
fi

# Compute services
if openstack compute service list &>/dev/null; then
    COMPUTE_UP=$(openstack compute service list -f value -c State | grep -c "up" || true)
    COMPUTE_DOWN=$(openstack compute service list -f value -c State | grep -c "down" || true)
    if [[ $COMPUTE_DOWN -eq 0 ]]; then
        check_pass "Compute services: $COMPUTE_UP services UP"
    else
        check_warn "Compute services: $COMPUTE_UP UP, $COMPUTE_DOWN DOWN"
    fi
else
    check_fail "Cannot query compute services"
fi

# Network agents
if openstack network agent list &>/dev/null; then
    NET_ALIVE=$(openstack network agent list -f value -c Alive | grep -c ":-)" || true)
    NET_DEAD=$(openstack network agent list -f value -c Alive | grep -c "xxx" || true)
    if [[ $NET_DEAD -eq 0 ]]; then
        check_pass "Network agents: $NET_ALIVE agents alive"
    else
        check_warn "Network agents: $NET_ALIVE alive, $NET_DEAD dead"
    fi
else
    check_fail "Cannot query network agents"
fi

# ============================================================
# 5. Infrastructure Services
# ============================================================
echo ""
echo -e "${CYAN}━━━ Infrastructure Services ━━━${NC}"

# MariaDB
if docker ps --format '{{.Names}}' | grep -q mariadb; then
    check_pass "MariaDB — running"
else
    check_fail "MariaDB — NOT running"
fi

# RabbitMQ
if docker ps --format '{{.Names}}' | grep -q rabbitmq; then
    check_pass "RabbitMQ — running"
else
    check_fail "RabbitMQ — NOT running"
fi

# Memcached
if docker ps --format '{{.Names}}' | grep -q memcached; then
    check_pass "Memcached — running"
else
    check_fail "Memcached — NOT running"
fi

# HAProxy
if docker ps --format '{{.Names}}' | grep -q haproxy; then
    check_pass "HAProxy — running"
else
    check_fail "HAProxy — NOT running"
fi

# Open vSwitch
if docker ps --format '{{.Names}}' | grep -q openvswitch; then
    check_pass "Open vSwitch — running"
else
    check_warn "Open vSwitch — NOT found (may use linuxbridge)"
fi

# ============================================================
# 6. Resource Summary
# ============================================================
echo ""
echo -e "${CYAN}━━━ Resource Summary ━━━${NC}"

echo "  Images:     $(openstack image list -f value 2>/dev/null | wc -l)"
echo "  Flavors:    $(openstack flavor list -f value 2>/dev/null | wc -l)"
echo "  Networks:   $(openstack network list -f value 2>/dev/null | wc -l)"
echo "  Routers:    $(openstack router list -f value 2>/dev/null | wc -l)"
echo "  Instances:  $(openstack server list --all-projects -f value 2>/dev/null | wc -l)"
echo "  Volumes:    $(openstack volume list --all-projects -f value 2>/dev/null | wc -l)"
echo "  Floating:   $(openstack floating ip list -f value 2>/dev/null | wc -l)"

# ============================================================
# Summary
# ============================================================
echo ""
echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  Health Check Summary${NC}"
echo -e "${BLUE}============================================================${NC}"
echo -e "  ${GREEN}✓ PASSED:${NC}  $PASS"
echo -e "  ${YELLOW}⚠ WARNINGS:${NC} $WARN"
echo -e "  ${RED}✗ FAILED:${NC}  $FAIL"
echo ""

TOTAL=$((PASS + FAIL))
if [[ $TOTAL -gt 0 ]]; then
    SCORE=$(( (PASS * 100) / TOTAL ))
    if [[ $SCORE -ge 90 ]]; then
        echo -e "  ${GREEN}Overall: ${SCORE}% — HEALTHY ✓${NC}"
    elif [[ $SCORE -ge 70 ]]; then
        echo -e "  ${YELLOW}Overall: ${SCORE}% — DEGRADED ⚠${NC}"
    else
        echo -e "  ${RED}Overall: ${SCORE}% — CRITICAL ✗${NC}"
    fi
fi
echo -e "${BLUE}============================================================${NC}"
