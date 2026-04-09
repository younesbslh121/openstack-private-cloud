# 📦 Installation Guide — OpenStack Private Cloud (Kolla-Ansible)

## Table of Contents
1. [Prerequisites](#1-prerequisites)
2. [VM Setup](#2-vm-setup)
3. [Network Configuration](#3-network-configuration)
4. [Automated Installation](#4-automated-installation)
5. [Manual Installation](#5-manual-installation)
6. [Post-Deployment](#6-post-deployment)
7. [Verification](#7-verification)
8. [Troubleshooting](#8-troubleshooting)

---

## 1. Prerequisites

### Hardware Requirements
| Resource | Minimum | Recommended |
|----------|---------|-------------|
| RAM | 8 GB | 16 GB |
| Disk | 60 GB | 100 GB |
| CPU | 4 cores | 8 cores |
| NICs | 2 | 2 |

### Software Requirements
- **Hypervisor**: VirtualBox 7.x or VMware Workstation 17+
- **Guest OS**: Debian 12 (Bookworm) — Server install *(Ubuntu 24.04 LTS also supported)*
- **Internet**: Stable connection for downloading packages

---

## 2. VM Setup

### VirtualBox Configuration

1. **Create New VM**:
   - Name: `openstack-cloud`
   - Type: Linux / Debian (64-bit)
   - RAM: 8192 MB (minimum)
   - Disk: 60 GB (dynamically allocated VDI)
   - CPU: 4 cores
   - Enable: PAE/NX, VT-x/AMD-V, Nested Paging

2. **Network Adapters**:
   
   **Adapter 1 (NAT)**:
   - Attached to: NAT
   - Purpose: Internet access for package downloads
   
   **Adapter 2 (Host-Only)**:
   - Attached to: Host-Only Adapter
   - Name: VirtualBox Host-Only Ethernet Adapter
   - Purpose: Management network + external provider network
   - Configure Host-Only Network:
     - IPv4: `192.168.56.1`
     - Mask: `255.255.255.0`
     - DHCP: Disabled

3. **Install Debian 12 (Bookworm)**:
   - Download: https://www.debian.org/download
   - Install with default settings
   - Create user (non-root)
   - Enable OpenSSH server during installation
   - **Important**: After install, add your user to sudo group:
     ```bash
     su -
     apt install sudo
     usermod -aG sudo your_username
     exit
     # Log out and back in
     ```

---

## 3. Network Configuration

### Identify Network Interfaces

```bash
ip -brief link show
# Debian typically uses one of these naming schemes:
#
# Traditional:     eth0, eth1
# Predictable:     enp0s3, enp0s8
#
# Example output:
# lo      UNKNOWN  00:00:00:00:00:00
# eth0    UP       08:00:27:xx:xx:xx    ← NAT (Adapter 1)
# eth1    UP       08:00:27:xx:xx:xx    ← Host-Only (Adapter 2)
```

> **Note**: The setup script auto-detects your interfaces. But if you need to configure manually, follow the steps below.

### Configure Network (Debian uses `/etc/network/interfaces`)

```bash
sudo nano /etc/network/interfaces
```

```
# The loopback interface
auto lo
iface lo inet loopback

# Management interface (NAT — Internet access)
auto eth0
iface eth0 inet dhcp

# External interface (Host-Only — for Neutron/floating IPs)
# This interface must be UP but WITHOUT an IP address
auto eth1
iface eth1 inet manual
    up ip link set $IFACE up
    down ip link set $IFACE down
```

Apply configuration:
```bash
sudo systemctl restart networking
# or
sudo ifup eth1
```

### Important: External Interface for Neutron

The external interface (`eth1`) will be taken over by Neutron's `br-ex` bridge. It must be UP but have **no IP address** — Neutron manages it.

---

## 4. Automated Installation

The easiest way to deploy is using the provided setup script:

```bash
# Clone the repository (on the VM)
git clone https://github.com/YOUR_USERNAME/openstack-private-cloud.git
cd openstack-private-cloud

# Make the script executable
chmod +x deployment/kolla-ansible/setup.sh

# Run the setup (takes 15-30 minutes)
./deployment/kolla-ansible/setup.sh
```

The script will:
1. ✅ Verify system requirements
2. ✅ Install system dependencies
3. ✅ Configure external network interface
4. ✅ Install and configure Docker
5. ✅ Create Python virtual environment
6. ✅ Install Kolla-Ansible
7. ✅ Configure globals.yml and passwords
8. ✅ Prepare Cinder LVM backend
9. ✅ Bootstrap servers
10. ✅ Run pre-deployment checks
11. ✅ Deploy OpenStack
12. ✅ Run post-deployment configuration

---

## 5. Manual Installation

If you prefer step-by-step manual installation:

### Step 1: System Dependencies

```bash
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y python3-dev python3-venv python3-pip \
    libffi-dev gcc libssl-dev libdbus-glib-1-dev \
    git curl wget jq bridge-utils net-tools \
    ca-certificates gnupg lsb-release \
    lvm2 thin-provisioning-tools sudo
```

### Step 2: Install Docker

```bash
curl -fsSL https://get.docker.com | sudo bash
sudo usermod -aG docker $USER
sudo systemctl enable docker && sudo systemctl start docker
```

### Step 3: Python Virtual Environment

```bash
python3 -m venv ~/kolla-venv
source ~/kolla-venv/bin/activate
pip install -U pip setuptools wheel
```

### Step 4: Install Kolla-Ansible

```bash
pip install 'ansible-core>=2.16,<2.18'
pip install git+https://opendev.org/openstack/kolla-ansible@master
kolla-ansible install-deps
```

### Step 5: Configuration

```bash
sudo mkdir -p /etc/kolla && sudo chown $USER:$USER /etc/kolla
cp -r ~/kolla-venv/share/kolla-ansible/etc_examples/kolla/* /etc/kolla/
cp ~/kolla-venv/share/kolla-ansible/ansible/inventory/all-in-one /etc/kolla/
```

Edit `/etc/kolla/globals.yml`:
```yaml
kolla_base_distro: "debian"
kolla_install_type: "source"
network_interface: "eth0"          # Your management NIC
neutron_external_interface: "eth1"  # Your external NIC
kolla_internal_vip_address: "192.168.56.250"
nova_compute_virt_type: "qemu"
enable_cinder: "yes"
enable_cinder_backend_lvm: "yes"
enable_heat: "yes"
neutron_plugin_agent: "openvswitch"
enable_neutron_provider_networks: "yes"
```
> **Note**: Replace `eth0`/`eth1` with your actual interface names from `ip -brief link show`

Generate passwords:
```bash
kolla-genpwd
```

### Step 6: Prepare Cinder LVM

```bash
sudo mkdir -p /var/lib/cinder
sudo dd if=/dev/zero of=/var/lib/cinder/cinder-volumes.img bs=1M count=20480
LOOP=$(sudo losetup -f)
sudo losetup $LOOP /var/lib/cinder/cinder-volumes.img
sudo pvcreate $LOOP
sudo vgcreate cinder-volumes $LOOP
```

### Step 7: Deploy

```bash
kolla-ansible bootstrap-servers -i /etc/kolla/all-in-one
kolla-ansible prechecks -i /etc/kolla/all-in-one
kolla-ansible deploy -i /etc/kolla/all-in-one
kolla-ansible post-deploy
```

### Step 8: Install CLI

```bash
pip install python-openstackclient python-heatclient python-cinderclient
```

---

## 6. Post-Deployment

### Configure credentials:
```bash
mkdir -p ~/.config/openstack
cp /etc/kolla/clouds.yaml ~/.config/openstack/
```

### Create demo resources:
```bash
cd openstack-private-cloud
chmod +x automation/scripts/create-demo-resources.sh
./automation/scripts/create-demo-resources.sh
```

### Start monitoring stack:
```bash
cd monitoring
docker-compose up -d
```

---

## 7. Verification

### Check all services:
```bash
openstack service list
openstack endpoint list
openstack compute service list
openstack network agent list
```

### Run health check:
```bash
./automation/scripts/health-check.sh
```

### Access Horizon:
- URL: `http://192.168.56.250`
- Username: `admin`
- Password: Check `/etc/kolla/passwords.yml` → `keystone_admin_password`

---

## 8. Troubleshooting

### Common Issues

**Docker containers not starting:**
```bash
docker ps -a --filter "status=exited"
docker logs <container_name>
```

**Kolla prechecks failing:**
```bash
# Check interface names
ip -brief link show

# Verify VIP is reachable
ping -c 3 192.168.56.250

# Check Docker
docker info
```

**Horizon not accessible:**
```bash
docker ps | grep horizon
docker logs horizon
# Check HAProxy
docker logs haproxy
```

**Instance launch fails:**
```bash
openstack server show <instance-id>
docker logs nova_compute
docker logs nova_scheduler
```

### Useful Commands
```bash
# Check all Kolla containers
docker ps --format 'table {{.Names}}\t{{.Status}}'

# Restart a service
docker restart <service_name>

# View service logs
docker logs -f --tail 100 <service_name>

# Re-deploy a specific service
kolla-ansible reconfigure -i /etc/kolla/all-in-one --tags nova

# Destroy and redeploy
kolla-ansible destroy --yes-i-really-really-mean-it -i /etc/kolla/all-in-one
```
