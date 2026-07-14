# Changelog

All notable changes to this project will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- `harbor_containers` role — syncs container images to Harbor through proxy
  cache projects, checks upstream for version updates matching same naming
  convention, generates YAML sync report.
- Upstream registries configured in Harbor:
  - Docker Hub (`docker.io`) → `docker-hub-cache` project
  - Quay.io (`quay.io`) → `quay-cache` project
  - GHCR (`ghcr.io`) → `ghcr-cache` project
- Container images synced to Harbor (15 images across library, prometheus):
  - Base: alpine, ubuntu, busybox
  - Application: nginx, redis, postgres, mariadb, python, node, golang
  - Monitoring: prometheus, alertmanager, grafana, node-exporter, pushgateway
- `meta/main.yml` for all roles with galaxy_info and dependencies.
- `.ansible-lint` configuration excluding role helper task files.
- `inventory/group_vars/harbor/images.yml` — container image definitions
  with registry, project, and proxy cache project mappings.
- `harbor_config_sync_projects` flag — auto-discovers projects from
  `harbor_sync_images` instead of requiring manual project definitions.

### Changed

- Renamed `playbooks/harbor-sync-images.yml` to `sync-update-containers.yml`.
- Extracted sync logic from playbook into `harbor_containers` role.
- `harbor_config` now creates projects from `harbor_sync_images` when
  `harbor_config_sync_projects: true` (single source of truth for projects).
- Version update check only matches tags with same naming convention
  (v-prefix, part count, suffix). E.g., `v3.3.0` → `v3.13.1`, not
  `v3.13.1-distroless`.
- Podman push uses shell command instead of `podman_image` module
  (bypasses remote verification that fails for new repositories).

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
