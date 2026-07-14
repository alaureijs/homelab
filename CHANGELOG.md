# Changelog

All notable changes to this project will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Four Harbor-related roles:
  - `podman` — installs Podman, configures registries, enables socket.
  - `certificates` — generates self-signed TLS certs with SANs or deploys provided ones.
  - `firewall` — configures firewalld ports (80/tcp, 443/tcp, 22/tcp).
  - `harbor` — offline Harbor install with Podman, configures and starts services.
  - `harbor_config` — manages Harbor users, projects, and roles via API.
- Playbooks:
  - `playbooks/provision-ansible01.yml` — provision ansible01 VM for Harbor.
  - `playbooks/harbor-users.yml` — configure Harbor users, projects, and roles.
  - `playbooks/harbor-sync-images.yml` — sync container images to Harbor.
  - `playbooks/harbor-certs.yml` — regenerate TLS certificates.
- Harbor configuration in `inventory/group_vars/harbor/main.yml`:
  - Harbor settings, ports, passwords, firewall rules.
  - User accounts with project roles.
  - Project definitions (proxy-cache).
- TLS certificates with SANs (Subject Alternative Names):
  - DNS: `harbor.local.lan`, `ansible01`
  - IP: `192.168.100.10`
- Harbor users managed via API:
  - `viewer` account with guest role (read-only access).
- All Harbor passwords stored in vault:
  - `vault_harbor_admin_password`
  - `vault_harbor_database_password`
  - `vault_harbor_redis_password`
  - `vault_harbor_viewer_password`

### Changed

- Refactored `host_vars` to directory-based structure:
  - `host_vars/web01.yml` → `host_vars/web01/main.yml`
  - New `host_vars/ansible01/main.yml` — connection, VM specs, network, DNS.
  - New `host_vars/ansible01/provision.yml` — Harbor, packages, firewall.
- `playbooks/provision-ansible01.yml` now uses variables from `host_vars`
  instead of hardcoded values.
- Removed inline `ansible_host` from `hosts.yml` for `ansible01` (moved to
  `host_vars/ansible01/main.yml`).
- Harbor `prepare` and compose patching now run on every playbook apply
  (not just initial install) to support certificate regeneration.
- Harbor passwords moved from plaintext in `group_vars/harbor/main.yml`
  to encrypted vault variables.

## [0.1.0] - 2026-07-13

### Added

- Initial Ansible project structure with `ansible.cfg`, inventory, and roles.
- Three sample roles: `common`, `nginx`, `postgres` with tasks and handlers.
- Main playbook `playbooks/site.yml` applying roles to host groups.
- Libvirt VM `ansible01` provisioned on host:
  - Rocky Linux 10.2 cloud image, 2 vCPU, 2 GB RAM, 60 GB disk.
  - NAT network `ansible-net` (192.168.100.0/24) with DHCP and DNS.
  - DNS entry: `harbor.local.lan` -> `192.168.100.10`.
  - UEFI (OVMF) boot, VirtIO NIC and disk.
- Storage pool `sdb` on `/dev/sdb` (XFS, autostarted, fstab entry).
- Cloud-init provisioning with SSH key (ed25519) and hostname.
- Ansible Vault for root password (`inventory/group_vars/all/vault.yml`).
- Provisioning playbook `playbooks/provision-ansible01.yml`:
  - Timezone, packages, firewalld, hostname, chronyd, `/etc/hosts`.
- `scripts/ufw-libvirt.sh` for UFW route rules on `virbr-ansible` bridge.
- `inventory/group_vars/libvirt.yml` for libvirt host group.
- README.md and CHANGELOG.md documentation.

### Fixed

- UFW blocking libvirt NAT traffic on `virbr-ansible` bridge.
  - Added route rules for guest cross-traffic and NAT forwarding.
- `stdout_callback = yaml` replaced with `ansible.builtin.default` +
  `callback_result_format = yaml` (community.general.yaml removed in v12).
- `ansible.posix.firewalld` `item` parameter renamed to `port`.

### Changed

- Removed `monitoring-lab` libvirt network (replaced by `ansible-net`).
- `inventory/group_vars/all.yml` no longer sets `ansible_user` globally;
  set per group instead.
