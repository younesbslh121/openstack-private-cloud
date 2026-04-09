<p align="center">
  <img src="https://upload.wikimedia.org/wikipedia/commons/thumb/e/e6/OpenStack%C2%AE_Logo_2016.svg/512px-OpenStack%C2%AE_Logo_2016.svg.png" alt="OpenStack Logo" width="300"/>
</p>

<h1 align="center">☁️ Private Cloud OpenStack — Kolla-Ansible</h1>

<p align="center">
  <em>Production-grade private cloud infrastructure built with OpenStack & automated with Terraform, Ansible, and Heat</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/OpenStack-2024.2-ED1944?style=for-the-badge&logo=openstack&logoColor=white" alt="OpenStack"/>
  <img src="https://img.shields.io/badge/Kolla--Ansible-Containerized-326CE5?style=for-the-badge&logo=ansible&logoColor=white" alt="Kolla-Ansible"/>
  <img src="https://img.shields.io/badge/Terraform-IaC-7B42BC?style=for-the-badge&logo=terraform&logoColor=white" alt="Terraform"/>
  <img src="https://img.shields.io/badge/Heat-Orchestration-FF6F00?style=for-the-badge&logo=openstack&logoColor=white" alt="Heat"/>
  <img src="https://img.shields.io/badge/Prometheus-Monitoring-E6522C?style=for-the-badge&logo=prometheus&logoColor=white" alt="Prometheus"/>
  <img src="https://img.shields.io/badge/Grafana-Dashboards-F46800?style=for-the-badge&logo=grafana&logoColor=white" alt="Grafana"/>
  <img src="https://img.shields.io/badge/Debian-12_Bookworm-A81D33?style=for-the-badge&logo=debian&logoColor=white" alt="Debian"/>
  <img src="https://img.shields.io/badge/Docker-Containerized-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker"/>
</p>

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Architecture](#-architecture)
- [OpenStack Services](#-openstack-services)
- [Tech Stack](#-tech-stack)
- [Prerequisites](#-prerequisites)
- [Installation](#-installation)
- [Infrastructure as Code](#-infrastructure-as-code-terraform)
- [Orchestration](#-orchestration-heat-templates)
- [Monitoring](#-monitoring-prometheus--grafana)
- [Screenshots](#-screenshots)
- [Project Structure](#-project-structure)
- [Author](#-author)

---

## 🎯 Overview

This project demonstrates the deployment of a **production-grade private cloud** using **OpenStack**, deployed via **Kolla-Ansible** (containerized microservices architecture). It showcases end-to-end cloud engineering skills including:

- 🏗️ **Cloud Infrastructure** — Full OpenStack deployment with 8+ services
- 🔐 **Identity Management** — Multi-tenant authentication with Keystone
- 🖥️ **Compute** — Virtual machine lifecycle management with Nova
- 🌐 **Software-Defined Networking** — Virtual networks, routers, floating IPs with Neutron
- 💾 **Storage** — Block storage volumes with Cinder, image management with Glance
- 🏗️ **Infrastructure as Code** — Automated provisioning with Terraform (OpenStack Provider)
- 🔥 **Stack Orchestration** — Auto-scaling web stacks with Heat (HOT templates)
- 📊 **Observability** — Real-time monitoring with Prometheus + Grafana dashboards
- ⚙️ **Configuration Management** — Automated setup with Ansible playbooks

> 🎓 **Academic Project** — 2nd Year Engineering Cycle @ INPT (Institut National des Postes et Télécommunications)

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        OPENSTACK PRIVATE CLOUD                         │
│                     Deployed via Kolla-Ansible                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐     │
│  │ Keystone │ │  Nova    │ │ Neutron  │ │  Glance  │ │  Cinder  │     │
│  │ Identity │ │ Compute  │ │ Network  │ │  Image   │ │ Storage  │     │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘     │
│       │            │            │            │            │             │
│  ┌────┴────────────┴────────────┴────────────┴────────────┴─────┐      │
│  │                    Message Queue (RabbitMQ)                    │      │
│  │                    Database (MariaDB/MySQL)                    │      │
│  └──────────────────────────────────────────────────────────────-┘      │
│                                                                         │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌───────────────────────┐      │
│  │ Horizon  │ │  Heat    │ │Placement │ │     Monitoring        │      │
│  │Dashboard │ │  Orch.   │ │ Service  │ │ Prometheus + Grafana  │      │
│  └──────────┘ └──────────┘ └──────────┘ └───────────────────────┘      │
│                                                                         │
├─────────────────────────────────────────────────────────────────────────┤
│                     AUTOMATION LAYER                                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐      │
│  │  Terraform   │  │   Ansible    │  │   Heat HOT Templates     │      │
│  │  IaC Provider│  │  Playbooks   │  │   Stack Orchestration    │      │
│  └──────────────┘  └──────────────┘  └──────────────────────────┘      │
├─────────────────────────────────────────────────────────────────────────┤
│                     INFRASTRUCTURE                                      │
│  ┌──────────────────────────────────────────────────────────────┐       │
│  │  Debian 12 Bookworm │ Docker Engine │ OVS │ KVM/QEMU       │       │
│  │  8GB RAM │ 60GB Disk │ 4 vCPUs │ 2 NICs (NAT + Host-Only) │       │
│  └──────────────────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 🔧 OpenStack Services

| Service | Component | Description | Port |
|---------|-----------|-------------|------|
| **Keystone** | Identity | Authentication, authorization, service catalog | 5000 |
| **Nova** | Compute | VM lifecycle management (create, resize, migrate) | 8774 |
| **Neutron** | Networking | Virtual networks, routers, floating IPs, security groups | 9696 |
| **Glance** | Image | OS image storage and management (QCOW2, RAW) | 9292 |
| **Cinder** | Block Storage | Persistent volume management for instances | 8776 |
| **Horizon** | Dashboard | Web-based UI for cloud management | 80/443 |
| **Placement** | Resource Tracking | Resource inventory and allocation | 8778 |
| **Heat** | Orchestration | Infrastructure stack templates (HOT/CFN) | 8004 |
| **RabbitMQ** | Message Queue | Inter-service AMQP messaging | 5672 |
| **MariaDB** | Database | Service state and configuration storage | 3306 |
| **Memcached** | Cache | Token and session caching | 11211 |
| **HAProxy** | Load Balancer | API endpoint high availability | 80/443 |

---

## 🛠️ Tech Stack

| Category | Technology | Purpose |
|----------|-----------|---------|
| **Cloud Platform** | OpenStack 2024.2 | Private cloud infrastructure |
| **Deployment** | Kolla-Ansible | Containerized OpenStack deployment |
| **Host OS** | Debian 12 (Bookworm) | Base operating system |
| **Containers** | Docker | Service isolation & management |
| **IaC** | Terraform 1.9+ | Infrastructure provisioning |
| **Orchestration** | Heat (HOT) | Stack-based resource management |
| **Config Mgmt** | Ansible | Automated configuration |
| **Monitoring** | Prometheus + Grafana | Metrics & visualization |
| **Virtualization** | KVM/QEMU | Hypervisor for instances |
| **Networking** | Open vSwitch (OVS) | Virtual switching |
| **Database** | MariaDB | Service state storage |
| **Messaging** | RabbitMQ | AMQP message broker |

---

## 📦 Prerequisites

### Hardware Requirements
| Resource | Minimum | Recommended |
|----------|---------|-------------|
| **RAM** | 8 GB | 16 GB |
| **Disk** | 60 GB | 100 GB |
| **CPU** | 4 cores | 8 cores |
| **NICs** | 2 | 2 |

### Software Requirements
- Debian 12 Bookworm *(Ubuntu 24.04 LTS also supported)*
- VirtualBox / VMware Workstation
- 2 Network Interfaces:
  - **NIC1** (NAT) — Internet access
  - **NIC2** (Host-Only) — Management network

---

## 🚀 Installation

### Quick Start
```bash
# Clone this repository
git clone https://github.com/YOUR_USERNAME/openstack-private-cloud.git
cd openstack-private-cloud

# Run the automated setup
chmod +x deployment/kolla-ansible/setup.sh
./deployment/kolla-ansible/setup.sh
```

### Step-by-Step Guide
See the detailed [Installation Guide](docs/installation-guide.md) for a complete walkthrough.

### Post-Deployment
```bash
# Create demo resources (networks, images, instances)
chmod +x automation/scripts/create-demo-resources.sh
./automation/scripts/create-demo-resources.sh

# Health check
chmod +x automation/scripts/health-check.sh
./automation/scripts/health-check.sh
```

---

## 🏗️ Infrastructure as Code (Terraform)

Provision cloud resources programmatically:

```bash
cd terraform/

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply infrastructure
terraform apply -auto-approve

# View outputs
terraform output
```

**Managed Resources:**
- ✅ Virtual networks & subnets
- ✅ Security groups & rules (SSH, HTTP, HTTPS)
- ✅ Compute instances with cloud-init
- ✅ Floating IP associations
- ✅ Block storage volumes

---

## 🔥 Orchestration (Heat Templates)

Deploy complete application stacks:

```bash
# Deploy a single instance
openstack stack create -t heat-templates/single-instance.yaml my-instance

# Deploy a web application stack
openstack stack create -t heat-templates/web-stack.yaml \
  -e heat-templates/env.yaml web-app-stack

# Deploy auto-scaling group
openstack stack create -t heat-templates/auto-scaling.yaml auto-scale-app
```

---

## 📊 Monitoring (Prometheus + Grafana)

```bash
cd monitoring/
docker-compose up -d
```

- **Prometheus**: http://HOST_IP:9090
- **Grafana**: http://HOST_IP:3000 (admin/admin)
- **OpenStack Exporter**: http://HOST_IP:9180/metrics

**Monitored Metrics:**
- Nova — Instance count, vCPU/RAM usage
- Neutron — Network/subnet/router count, floating IPs
- Cinder — Volume count, total capacity
- Keystone — Token count, project count
- Glance — Image count, total size

---

## 📸 Screenshots

<details>
<summary>🖼️ Click to expand screenshots</summary>

### Horizon Dashboard
> ![Horizon Dashboard](docs/screenshots/horizon-dashboard.png)

### Running Instances
> ![Instances](docs/screenshots/horizon-instances.png)

### Network Topology
> ![Network Topology](docs/screenshots/horizon-network-topology.png)

### CLI Output
> ![CLI](docs/screenshots/cli-server-list.png)

### Grafana Monitoring
> ![Grafana](docs/screenshots/grafana-monitoring.png)

### Terraform Apply
> ![Terraform](docs/screenshots/terraform-apply.png)

</details>

---

## 📁 Project Structure

```
openstack-private-cloud/
├── README.md
├── docs/
│   ├── architecture.md
│   ├── installation-guide.md
│   ├── user-guide.md
│   └── screenshots/
├── deployment/
│   └── kolla-ansible/
│       ├── globals.yml
│       ├── passwords.yml.template
│       ├── setup.sh
│       └── ansible/
│           ├── inventory/
│           │   ├── all-in-one
│           │   └── multinode
│           └── playbooks/
│               └── post-deploy.yml
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── network.tf
│   ├── instances.tf
│   ├── security_groups.tf
│   └── terraform.tfvars.example
├── heat-templates/
│   ├── single-instance.yaml
│   ├── web-stack.yaml
│   ├── auto-scaling.yaml
│   └── env.yaml
├── automation/
│   ├── ansible/
│   │   ├── playbook-setup-tenant.yml
│   │   ├── playbook-deploy-app.yml
│   │   └── inventory.yml
│   └── scripts/
│       ├── create-demo-resources.sh
│       ├── cleanup.sh
│       └── health-check.sh
├── monitoring/
│   ├── docker-compose.yml
│   ├── prometheus/
│   │   └── prometheus.yml
│   └── grafana/
│       └── dashboards/
│           └── openstack-overview.json
└── .github/
    └── README-linkedin.md
```

---

## 👤 Author

**Younes Boussalah** — 2nd Year Engineering Student @ INPT

- 🎓 Institut National des Postes et Télécommunications
- 🔗 [LinkedIn](https://linkedin.com/in/YOUR_PROFILE)
- 🐙 [GitHub](https://github.com/YOUR_USERNAME)

---

## 📝 License

This project is licensed under the MIT License 

---

<p align="center">
  <strong>⭐ If you found this project helpful, please give it a star!</strong>
</p>
