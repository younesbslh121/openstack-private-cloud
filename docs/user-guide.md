# 📖 User Guide — OpenStack Private Cloud

## Table of Contents
1. [Accessing OpenStack](#1-accessing-openstack)
2. [Managing Instances](#2-managing-instances)
3. [Networking](#3-networking)
4. [Storage](#4-storage)
5. [Heat Orchestration](#5-heat-orchestration)
6. [Terraform Automation](#6-terraform-automation)
7. [Monitoring](#7-monitoring)
8. [CLI Reference](#8-cli-reference)

---

## 1. Accessing OpenStack

### Web Dashboard (Horizon)
- **URL**: `http://192.168.56.250`
- **Domain**: `default`
- **Username**: `admin`
- **Password**: See `/etc/kolla/passwords.yml` → `keystone_admin_password`

### CLI (Command Line)
```bash
# Activate virtual environment
source ~/kolla-venv/bin/activate

# Set credentials
export OS_CLIENT_CONFIG_FILE=/etc/kolla/clouds.yaml
export OS_CLOUD=kolla-admin

# Verify connection
openstack token issue
```

---

## 2. Managing Instances

### Create an Instance (CLI)
```bash
# List available images
openstack image list

# List available flavors
openstack flavor list

# List available networks
openstack network list

# Create instance
openstack server create \
  --image CirrOS-0.6.2 \
  --flavor m1.small \
  --network internal-net \
  --security-group web-sg \
  --key-name default-keypair \
  my-server

# Check status
openstack server show my-server
```

### Create an Instance (Horizon)
1. Navigate to **Project → Compute → Instances**
2. Click **Launch Instance**
3. Fill in:
   - Name: `my-server`
   - Source: `CirrOS-0.6.2`
   - Flavor: `m1.small`
   - Network: `internal-net`
   - Security Groups: `web-sg`
   - Key Pair: `default-keypair`
4. Click **Launch Instance**

### Assign Floating IP
```bash
# Create a floating IP from external pool
openstack floating ip create external-net

# Assign to instance
openstack server add floating ip my-server 192.168.56.XXX

# SSH into instance
ssh -i ~/.ssh/openstack-key cirros@192.168.56.XXX
```

### Instance Lifecycle
```bash
openstack server stop my-server      # Stop
openstack server start my-server     # Start
openstack server reboot my-server    # Reboot
openstack server pause my-server     # Pause
openstack server unpause my-server   # Unpause
openstack server resize my-server --flavor m1.medium  # Resize
openstack server delete my-server    # Delete
```

---

## 3. Networking

### Create a Network
```bash
# Create network
openstack network create my-network

# Create subnet
openstack subnet create my-subnet \
  --network my-network \
  --subnet-range 10.1.0.0/24 \
  --dns-nameserver 8.8.8.8

# Create router and connect
openstack router create my-router
openstack router set my-router --external-gateway external-net
openstack router add subnet my-router my-subnet
```

### Security Groups
```bash
# Create security group
openstack security group create my-sg

# Add rules
openstack security group rule create my-sg \
  --protocol tcp --dst-port 22 --remote-ip 0.0.0.0/0
openstack security group rule create my-sg \
  --protocol tcp --dst-port 80 --remote-ip 0.0.0.0/0
openstack security group rule create my-sg \
  --protocol icmp --remote-ip 0.0.0.0/0

# List rules
openstack security group rule list my-sg
```

### View Network Topology
In Horizon: **Project → Network → Network Topology**

---

## 4. Storage

### Block Storage (Cinder)
```bash
# Create a volume
openstack volume create --size 10 my-volume

# Attach to instance
openstack server add volume my-server my-volume

# Detach from instance
openstack server remove volume my-server my-volume

# Create snapshot
openstack volume snapshot create --volume my-volume my-snapshot

# Delete volume
openstack volume delete my-volume
```

### Images (Glance)
```bash
# Upload image
openstack image create "Ubuntu-24.04" \
  --file noble-server-cloudimg-amd64.img \
  --disk-format qcow2 \
  --container-format bare \
  --public

# List images
openstack image list

# Download image
openstack image save --file output.img Ubuntu-24.04
```

---

## 5. Heat Orchestration

### Deploy a Single Instance Stack
```bash
openstack stack create \
  -t heat-templates/single-instance.yaml \
  my-instance-stack

# Check status
openstack stack show my-instance-stack

# List stack resources
openstack stack resource list my-instance-stack

# Delete stack
openstack stack delete my-instance-stack --yes
```

### Deploy a Web Application Stack
```bash
openstack stack create \
  -t heat-templates/web-stack.yaml \
  -e heat-templates/env.yaml \
  --parameter instance_count=3 \
  web-app-stack
```

### Deploy Auto-Scaling Group
```bash
openstack stack create \
  -t heat-templates/auto-scaling.yaml \
  --parameter min_size=1 \
  --parameter max_size=5 \
  --parameter desired_capacity=2 \
  auto-scale-stack

# Manual scale-up (via webhook)
SCALE_UP_URL=$(openstack stack output show auto-scale-stack scale_up_url -f value -c output_value)
curl -X POST "$SCALE_UP_URL"

# Manual scale-down
SCALE_DOWN_URL=$(openstack stack output show auto-scale-stack scale_down_url -f value -c output_value)
curl -X POST "$SCALE_DOWN_URL"
```

---

## 6. Terraform Automation

### Initialize and Apply
```bash
cd terraform/

# Copy example variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Initialize
terraform init

# Plan
terraform plan

# Apply
terraform apply

# View outputs
terraform output

# Destroy
terraform destroy
```

### What Terraform Creates
- App network + subnet
- Router connected to external network
- Web security group (SSH, HTTP, HTTPS, ICMP)
- Database security group (MySQL internal only)
- 2 web server instances with cloud-init
- Floating IPs for each instance
- 10GB data volume attached to first instance

---

## 7. Monitoring

### Start Monitoring Stack
```bash
cd monitoring/
docker-compose up -d
```

### Access Dashboards
| Service | URL | Credentials |
|---------|-----|-------------|
| Grafana | http://HOST:3000 | admin / admin |
| Prometheus | http://HOST:9090 | — |
| Node Exporter | http://HOST:9100/metrics | — |
| OpenStack Exporter | http://HOST:9180/metrics | — |

### Key Metrics
- **Nova**: Running instances, vCPU usage, RAM consumption
- **Neutron**: Networks, subnets, routers, floating IPs
- **Cinder**: Volumes, total capacity
- **Host**: CPU%, Memory%, Disk I/O, Network traffic

---

## 8. CLI Reference

### Quick Reference
```bash
# Identity
openstack project list
openstack user list
openstack role assignment list

# Compute
openstack server list
openstack server create/delete/show
openstack flavor list
openstack hypervisor stats show

# Network
openstack network list
openstack subnet list
openstack router list
openstack floating ip list
openstack security group list

# Storage
openstack image list
openstack volume list
openstack volume snapshot list

# Orchestration
openstack stack list
openstack stack create/delete/show
openstack stack resource list

# Service Status
openstack service list
openstack endpoint list
openstack compute service list
openstack network agent list
```

### Environment Variables
```bash
export OS_CLIENT_CONFIG_FILE=/etc/kolla/clouds.yaml
export OS_CLOUD=kolla-admin
```
