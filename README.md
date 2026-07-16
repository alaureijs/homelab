# Ansible Infrastructure

Ansible project for managing infrastructure, including libvirt virtual machines.

## Project Structure

```
ansible/
├── ansible.cfg                          # Ansible configuration
├── .ansible-lint                        # Linter configuration
├── inventory/
│   ├── hosts.yml                        # Inventory (all host groups)
│   ├── group_vars/
│   │   ├── all.yml                      # Global variables
│   │   ├── all/vault.yml                # Encrypted secrets (ansible-vault)
│   │   ├── all/versions.yml             # Centralized version management
│   │   ├── harbor/                      # Harbor group vars (all Harbor settings)
│   │   │   ├── main.yml                 # Harbor version, ports, passwords, firewall
│   │   │   └── images.yml               # Container images for sync, proxy projects
│   │   ├── libvirt/                     # Libvirt group vars (VM defaults)
│   │   │   └── main.yml                 # VM specs, network, DNS, connection
│   │   ├── webservers.yml               # Webserver group vars
│   │   └── dbservers.yml                # Database group vars
│   └── host_vars/
│       ├── web01/main.yml               # Web01 host variables
│       └── ansible01/
│           ├── main.yml                 # Host-specific (IP, MAC, hostname)
│           └── provision.yml            # General provisioning (timezone, packages)
├── playbooks/
│   ├── site.yml                         # Main playbook (webservers, dbservers)
│   ├── provision-ansible01.yml          # Provision ansible01 VM for Harbor
│   ├── harbor-users.yml                 # Configure Harbor users, projects, roles
│   ├── harbor-certs.yml                 # Regenerate TLS certificates
│   └── sync-update-containers.yml       # Sync images and check upstream versions
├── roles/
│   ├── common/                          # Base packages, NTP
│   ├── nginx/                           # Web server with templated config
│   ├── postgres/                        # PostgreSQL installation
│   ├── podman/                          # Podman installation and configuration
│   ├── certificates/                    # TLS certificate generation with SANs
│   ├── firewall/                        # Firewalld port configuration
│   ├── harbor/                          # Harbor offline install with Podman
│   ├── harbor_config/                   # Harbor users, projects, registries via API
│   ├── harbor_containers/               # Sync container images to Harbor
│   └── monitoring/                      # Monitoring stack (Grafana, Prometheus, etc.)
└── scripts/
    └── ufw-libvirt.sh                   # UFW rules for libvirt networks
```

## Requirements

- Ansible >= 2.17
- `ansible.posix`, `community.crypto`, `containers.podman` collections
- SSH access to target hosts
- `ansible-vault` for encrypted variables

## Quick Start

```bash
# Install required collections
ansible-galaxy collection install ansible.posix community.crypto containers.podman

# Syntax check
ansible-playbook playbooks/site.yml --syntax-check

# Dry run
ansible-playbook playbooks/site.yml --check

# Limit to a group
ansible-playbook playbooks/site.yml --limit webservers

# Run all
ansible-playbook playbooks/site.yml
```

## Inventory

| Group        | Host      | IP              | Description         |
|--------------|-----------|-----------------|---------------------|
| webservers   | web01     | 192.168.1.10    | Web server          |
| webservers   | web02     | 192.168.1.11    | Web server          |
| dbservers    | db01      | 192.168.1.20    | Database server     |
| monitoring   | ansible02 | 192.168.100.11  | Monitoring (Rocky 10 VM) |
| harbor       | ansible01 | 192.168.100.10  | Harbor (Rocky 10 VM)|
| libvirt      | ansible01 | 192.168.100.10  | Rocky Linux 10 VM   |
| libvirt      | ansible02 | 192.168.100.11  | Rocky Linux 10 VM   |

## Libvirt VM: ansible01

A Rocky Linux 10 VM managed by libvirt, provisioned for running Harbor.

### VM Specifications

All VM variables are defined in `inventory/host_vars/ansible01/`:

**`main.yml`** — connection and hardware:

| Variable       | Value                                  |
|----------------|----------------------------------------|
| ansible_host   | 192.168.100.10                         |
| vm_vcpus       | 2                                      |
| vm_memory      | 2048                                   |
| vm_disk        | 60                                     |
| vm_network     | ansible-net                            |
| vm_mac         | 52:54:00:aa:00:10                      |

**`provision.yml`** — software and services:

| Variable            | Value                              |
|---------------------|------------------------------------|
| timezone            | Europe/Amsterdam                   |
| firewall_ports      | 80, 443, 22                        |

## Libvirt VM: ansible02

A Rocky Linux 10 VM managed by libvirt, running the monitoring stack.
DNS name: `monitoring.local.lan` (in `monitoring` inventory group).

### VM Specifications

All VM variables are defined in `inventory/host_vars/ansible02/`:

| Variable       | Value                                  |
|----------------|----------------------------------------|
| ansible_host   | 192.168.100.11                         |
| vm_vcpus       | 2                                      |
| vm_memory      | 4096                                   |
| vm_disk        | 80                                     |
| vm_network     | ansible-net                            |
| vm_mac         | 52:54:00:aa:00:11                      |

### Monitoring Stack

Deployed via `podman kube play` with a K8s YAML manifest on a Podman CNI
network (`monitoring`). Prometheus scrapes node-exporter via FQDN with mTLS.

| Service       | Image (from Harbor)                    | Port  |
|---------------|----------------------------------------|-------|
| Grafana       | library/grafana/grafana                | 3000  |
| Prometheus    | prometheus/prometheus/prometheus        | 9090  |
| Alertmanager  | prometheus/prometheus/alertmanager      | 9093  |
| Node Exporter | prometheus/prometheus/node-exporter     | 9100 |

- Container versions defined in `inventory/group_vars/all/versions.yml`
- Services exposed to host via `hostPort` (127.0.0.1) for nginx reverse proxy
- nginx reverse proxy on port 443 with TLS
- Access via `https://monitoring.local.lan/grafana/` and `https://monitoring.local.lan/prometheus/`
- Cockpit auto-disabled (port 9090 conflict with Prometheus)
- SELinux configured for nginx network connectivity

### Managing the VM

```bash
# VM lifecycle
virsh list --all                        # List VMs
virsh start ansible01                   # Start
virsh shutdown ansible01                # Graceful shutdown
virsh destroy ansible01                 # Force stop
virsh undefine ansible01 --nvram        # Remove (keeps disk)
virsh console ansible01                 # Serial console
virsh domifaddr ansible01               # Show IP addresses

# Network
virsh net-list --all                    # List networks
virsh net-dhcp-leases ansible-net       # DHCP leases
virsh net-dumpxml ansible-net           # Network XML

# Storage
virsh pool-list --all                   # List pools
virsh pool-info sdb                     # Pool status
```

### Provisioning

```bash
# Run the provisioning playbook
ansible-playbook playbooks/provision-ansible01.yml

# Check connectivity
ansible ansible01 -m ping

# SSH in
ssh root@192.168.100.10
```

### Provisioning ansible02

```bash
# Run the provisioning playbook
ansible-playbook playbooks/provision-ansible02.yml

# Check connectivity
ansible ansible02 -m ping

# SSH in
ssh root@192.168.100.11
```

### Harbor Management

```bash
# Configure Harbor users, projects, and roles
ansible-playbook playbooks/harbor-users.yml

# Sync container images to Harbor for offline usage
ansible-playbook playbooks/sync-update-containers.yml

# Regenerate TLS certificates (restarts Harbor)
ansible-playbook playbooks/harbor-certs.yml
```

The sync playbook pulls images through proxy cache projects (auto-caches
from upstream registries), then pushes them to non-proxy Harbor projects.
Service account credentials are written to a temporary `auth.json` file
(workaround for broken `podman login` in Podman 5.8.2).

### Harbor Configuration

Users, projects, registries, and proxy cache projects are managed via the `harbor_config` role.

**Role IDs:**

| ID | Role           | Description                                    |
|----|----------------|------------------------------------------------|
| 1  | projectAdmin   | Full project management (members, settings, scans, deletion) |
| 2  | developer      | Read/write access (push images, create tags, scan) |
| 3  | guest          | Read-only access (pull images, retag)          |
| 4  | maintainer     | Elevated permissions (scan, replication, delete artifacts) |
| 5  | limitedGuest   | Pull only (no retag, no logs, no member visibility) |

**Configuration in `inventory/group_vars/harbor/main.yml`:**

```yaml
harbor_config_users:
  - username: viewer
    password: "{{ vault_harbor_viewer_password }}"
    realname: "Viewer Account"
    email: viewer@local.lan
    roles:
      - project_name: library
        role_id: 3
  - username: ansible-config
    password: "{{ vault_harbor_config_password }}"
    realname: "Ansible Config User"
    email: ansible-config@local.lan
    roles:
      - project_name: library
        role_id: 1
  - username: ansible-sync
    password: "{{ vault_harbor_sync_password }}"
    realname: "Ansible Sync User"
    email: ansible-sync@local.lan
    roles:
      - project_name: library
        role_id: 2

harbor_config_projects: []
harbor_config_sync_projects: true  # auto-discover projects from harbor_sync_images

harbor_config_registries:
  - name: docker-hub
    url: https://hub.docker.com
    type: docker-hub
  - name: quay
    url: https://quay.io
    type: quay
  - name: ghcr
    url: https://ghcr.io
    type: github-ghcr
```

The `harbor_config` role manages Harbor users, projects, and registries via
the Harbor API. Service accounts (`ansible-config`, `ansible-sync`) are
normal Harbor users, not robot accounts — Harbor v2.11 robot accounts are
incompatible with Podman login.

**Container images in `inventory/group_vars/harbor/images.yml`:**

Versions are referenced from `inventory/group_vars/all/versions.yml`:

```yaml
harbor_sync_images:
  - name: library/alpine
    tag: "{{ alpine_version }}"
    registry: docker.io
    project: library

  - name: prometheus/prometheus
    tag: "{{ prometheus_version }}"
    registry: quay.io
    project: prometheus

harbor_config_proxy_projects:
  docker.io: docker-hub-cache
  quay.io: quay-cache
  ghcr.io: ghcr-cache
```

The `harbor_containers` role syncs images through proxy cache projects (auto-caches upstream) and checks for upstream updates matching the same naming convention.

### Vault

All passwords are stored encrypted in `inventory/group_vars/all/vault.yml`:

- `vault_root_password` — VM root password
- `vault_harbor_admin_password` — Harbor admin (system) password
- `vault_harbor_database_password` — Harbor database password
- `vault_harbor_redis_password` — Harbor Redis password
- `vault_harbor_viewer_password` — Harbor viewer account password
- `vault_harbor_config_password` — Harbor config user password (projectAdmin)
- `vault_harbor_sync_password` — Harbor sync user password (developer, push/pull)
- `vault_monitoring_grafana_password` — Grafana admin password

### Cloud-init

Cloud-init ISO is generated at `/var/lib/libvirt/sdb/ansible01-cloudinit.iso`.
To regenerate after changes:

```bash
cloud-localds /tmp/cloud-init.iso /tmp/user-data
sudo cp /tmp/cloud-init.iso /var/lib/libvirt/sdb/ansible01-cloudinit.iso
```

Note: the VM must be destroyed and recreated for cloud-init to re-apply.

### UFW Rules (Host)

UFW on the host blocks libvirt bridge traffic by default. Run the script
after any UFW reset or reload:

```bash
sudo ./scripts/ufw-libvirt.sh
```

This adds route rules for `virbr-ansible` to allow:
- Guest cross-traffic (DHCP, DNS)
- NAT forwarding to all external interfaces (wlan1, enp109s0f1, etc.)

### Vault Management

```bash
# View vault password file
cat .vault_password

# Edit encrypted vars
ansible-vault edit inventory/group_vars/all/vault.yml

# View encrypted vars
ansible-vault view inventory/group_vars/all/vault.yml

# Add a new encrypted variable
ansible-vault encrypt_string 'my-secret' --name 'vault_new_password'
```

## Host Firewall (UFW)

The host runs UFW with default deny. Required rules:

```
Anywhere on virbr-ansible         ALLOW IN    Anywhere
Anywhere on virbr-ansible         ALLOW FWD   Anywhere on virbr-ansible
Anywhere                          ALLOW FWD   Anywhere on virbr-ansible
```

Use `scripts/ufw-libvirt.sh` to apply these automatically.

## Environment

- **Host OS**: CachyOS (Arch-based), kernel 7.1.x
- **Libvirt**: 12.5.0
- **Python**: 3.14.6
- **Storage pool**: `sdb` on `/dev/sdb` (XFS, 465 GB Samsung SSD)
- **Network**: `ansible-net` (NAT, bridge `virbr-ansible`)

## License

Internal use.
