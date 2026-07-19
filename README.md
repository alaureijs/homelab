# Ansible Infrastructure

Ansible project for managing infrastructure, including libvirt virtual machines, Harbor container registry, and monitoring stack.

## Requirements

- Ansible >= 2.17
- `ansible.posix`, `community.crypto`, `community.libvirt`, `containers.podman` collections
- `ansible-vault` for encrypted variables

```bash
ansible-galaxy collection install ansible.posix community.crypto community.libvirt containers.podman
```

## Inventory

| Group        | Host      | IP              | Role                                    |
|--------------|-----------|-----------------|-----------------------------------------|
| harbor       | ansible01 | 192.168.100.10  | Harbor v2.11.0 container registry       |
| monitoring   | ansible02 | 192.168.100.11  | Grafana/Prometheus/Alertmanager stack   |
| elk          | ansible03 | 192.168.100.12  | Elasticsearch/Logstash/Kibana stack     |
| libvirt      | all three |                 | Rocky Linux 10 VMs on `ansible-net`     |

DNS: `harbor.local.lan` (192.168.100.10), `monitoring.local.lan` (192.168.100.11), `observability.local.lan` (192.168.100.12)

## Quick Start

```bash
# Create/update libvirt VMs, network, and storage pool
ansible-playbook playbooks/libvirt.yml

# Provision Harbor (ansible01)
ansible-playbook playbooks/provision-ansible01.yml

# Provision monitoring (ansible02)
ansible-playbook playbooks/provision-ansible02.yml

# Provision ELK stack (ansible03)
ansible-playbook playbooks/provision-ansible03.yml

# Sync container images to Harbor
ansible-playbook playbooks/sync-update-containers.yml

# Configure Harbor users/projects
ansible-playbook playbooks/harbor-users.yml
```

## Playbooks

| Playbook | Description |
|----------|-------------|
| `libvirt.yml` | Create/update libvirt VMs, network, and storage pool |
| `provision-ansible01.yml` | Full provisioning for Harbor host |
| `provision-ansible02.yml` | Full provisioning for monitoring host |
| `provision-ansible03.yml` | Full provisioning for ELK stack host |
| `sync-update-containers.yml` | Sync images to Harbor / check upstream updates |
| `harbor-users.yml` | Manage Harbor users, projects, registries |
| `harbor-certs.yml` | Regenerate Harbor TLS certificates |
| `hardening.yml` | Standalone STIG/CIS hardening |

## Roles

| Role | Description |
|------|-------------|
| `libvirt` | Libvirt VM provisioning (storage pool, network, cloud-init, UEFI) |
| `common` | Package management, protected packages, /etc/hosts, chrony |
| `podman` | Podman/Buildah/Skopeo installation |
| `certificates` | TLS certificate generation with SANs (list-based) |
| `firewall` | Firewalld port configuration |
| `harbor` | Harbor offline install with Podman, metrics endpoint |
| `harbor_config` | Harbor users, projects, registries via API |
| `harbor_containers` | Sync container images to Harbor |
| `monitoring` | Grafana, Prometheus, Alertmanager, node-exporter |
| `node_exporter` | Node Exporter with mTLS |
| `elk` | Elasticsearch, Logstash, Kibana, Elasticsearch Exporter |
| `hardening` | STIG/CIS system hardening (10 toggleable modules) |

## Environment

- **Host OS**: CachyOS (Arch-based), kernel 7.1.x
- **VMs**: Rocky Linux 10.2 (libvirt, UEFI, VirtIO)
- **Network**: `ansible-net` NAT (192.168.100.0/24, bridge `virbr-ansible`)
- **Storage**: `sdb` pool on `/var/lib/libvirt/sdb` (dir-backed, 465 GB)

## Documentation

- [LIFECYCLE.md](LIFECYCLE.md) — Version management, update procedures, certificate renewal
- [docs/harbor.md](docs/harbor.md) — Harbor configuration, logging, management
- [docs/monitoring.md](docs/monitoring.md) — Monitoring stack details, mTLS, troubleshooting
- [docs/monitoring-configuration.md](docs/monitoring-configuration.md) — Monitoring configuration manual (without role changes)
- [docs/elasticsearch.md](docs/elasticsearch.md) — ELK stack deployment, configuration, troubleshooting
- [docs/elk-configuration.md](docs/elk-configuration.md) — ELK configuration manual (without role changes)
- [docs/hardening.md](docs/hardening.md) — Hardening modules, SELinux, audit rules
- [docs/vm.md](docs/vm.md) — VM lifecycle, cloud-init, host UFW
- [docs/cloud-kvm.md](docs/cloud-kvm.md) — Setting up VMs with cloud images in KVM

## License

Internal use.
