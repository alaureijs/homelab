# Changelog

All notable changes to this project will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- `ansible03` host — Rocky Linux 10 VM (2 vCPU, 8 GB RAM, 120 GB disk)
  at `192.168.100.12` on `ansible-net` network.
- `elk` inventory group with `group_vars/elk/main.yml`.
- `playbooks/provision-ansible03.yml` — provisioning playbook for
  ELK stack hosts (timezone, packages, firewall, certificates, podman,
  hardening, node_exporter, elk role).
- `inventory/host_vars/ansible03/` — VM specs and provisioning variables.
- `elk` role — deploys Elasticsearch/Logstash/Kibana stack on ansible03:
  - Elasticsearch 8.17.0 (single-node, security disabled, 4g heap)
  - Logstash 8.17.0 (beats input, grok filters, ES output, 2g heap)
  - Kibana 8.17.0 (HTTP 5601, connected to Elasticsearch)
  - All images pulled from Harbor registry
  - `podman kube play` with K8s YAML manifest
  - Podman CNI network (`elk`) for container networking
  - Hostname-based routing via nginx reverse proxy (HTTPS on 443)
  - `/kibana/` → Kibana (5601), `/elasticsearch/` → Elasticsearch (9200)
  - Host volume mounts for configs (Logstash config/pipeline split)
  - Elasticsearch data directory ownership fix (uid 1000) on deploy
  - Harbor TLS trust and auth.json for image pulls
  - rsyslog + logrotate for container log management
- `observability.local.lan` DNS entry in `ansible-net` network → 192.168.100.12.
- ELK container images synced to Harbor:
  - elasticsearch:8.17.0, logstash:8.17.0, kibana:8.17.0
- Harbor container logging to `/var/log/harbor/` via host rsyslog (journald
  → per-container files). Logrotate with 14-day retention, daily rotation.
- `hardening` playbook — standalone playbook for running hardening on any host.
- `hardening` role added to `provision-ansible01.yml` and `provision-ansible02.yml`.
- `hardening` role — STIG and CIS Benchmark system hardening for Rocky Linux 10:
  - Kernel/network hardening (sysctl): IP forwarding, source routing, ICMP
    redirects, SYN cookies, log martians, RFC 1337, reverse path filtering
  - SSH hardening: protocol 2, restricted algorithms (STIG-approved ciphers,
    MACs, KexAlgorithms), X11 forwarding disabled, idle timeout, max auth tries
  - File permissions: sticky bit on world-writable dirs, core dump restrictions,
    cron ownership, umask 027
  - Service hardening: disable unnecessary services (avahi, cups, rpcbind,
    bluetooth, udisks2, gssproxy, kdump, mdmonitor, sssd, rngd, etc.),
    mask rsh services, disable unused kernel modules (cramfs, freevxfs, hfs, udf,
    dccp, sctp, rds, tipc, USB storage)
  - Password/auth: pwquality (minlen 14, complexity), faillock (5 attempts,
    15min lockout), password history (5), SHA-512, aging policies
  - Audit logging: auditd with CIS 4.1 rules (identity, authorization,
    logins, file deletion, privilege escalation, MAC policy, time/network changes)
  - Warning banners: login and SSH authorized users notice
  - Resource limits: nofile/nproc 65536
  - All modules independently toggleable via `hardening_*` defaults
- `ansible02` host — Rocky Linux 10 VM (2 vCPU, 4 GB RAM, 80 GB disk)
  at `192.168.100.11` on `ansible-net` network.
- `monitoring` inventory group with `group_vars/monitoring/main.yml`.
- `playbooks/provision-ansible02.yml` — provisioning playbook for
  monitoring hosts (timezone, packages, firewall, certificates).
- `inventory/host_vars/ansible02/` — VM specs and provisioning variables.
- `monitoring` role — deploys monitoring stack on ansible02:
  - Grafana, Prometheus, Alertmanager, Node Exporter (versions in `all/main.yml`)
  - All images pulled from Harbor proxy cache projects
  - `podman kube play` with K8s YAML manifest
  - Podman CNI network (`monitoring`) for container networking
  - Hostname-based routing via nginx reverse proxy (HTTPS on 443)
  - SELinux configured for nginx network connectivity
  - Cockpit auto-disabled (port 9090 conflict with Prometheus)
  - Podman auth.json written for `podman kube play` (no `--authfile` support)
  - Data directory ownership: grafana=472, prometheus/alertmanager=65534
  - mTLS for node-exporter scraping (monitoring CA, server/client certs)
  - Prometheus scrapes node-exporter via FQDN from inventory (not localhost)
  - node-exporter binds to host IP (not 127.0.0.1)
- `node_exporter` role — binary install, systemd service, TLS web config.
- Certificate auto-renewal — both `certificates` and `monitoring` roles
  check certificate expiry via `x509_certificate_info` and regenerate
  when within `certificates_renew_threshold_days` (default 30 days).
  Force renewal via `certificates_force_renewal` / `monitoring_cert_force_renewal`
  extra vars. CA renewal cascades to dependent server/client certs.
- `inventory/group_vars/all/main.yml` — centralized version management
  for all container images and platform components (single source of truth).
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
- Normal Harbor service accounts (`ansible-config`, `ansible-sync`) with
  vault-encrypted passwords for config management and image push/pull.
- Trivy vulnerability scanner enabled in Harbor with auto-scan on all
  projects.
- `monitoring.local.lan` DNS entry in `ansible-net` network → 192.168.100.11.

### Changed

- `harbor_hostname` moved from `group_vars/harbor/main.yml` and
  `group_vars/monitoring/main.yml` to `group_vars/all/main.yml`
  (single source of truth).
- `roles/harbor/defaults/main.yml` — removed duplicate `harbor_hostname`
  variable (now centralized in `group_vars/all/main.yml`).
- `certificates` role — fixed `epoch_time` filter error (replaced with
  raw epoch output in certificates status debug message).
- `elk` role deploy task — runs `chown -R 1000:1000` on Elasticsearch
  data directory after `kube play` to fix permission denied errors.
- ELK container volumes restructured — separate host directories for
  Logstash config and pipeline to avoid `subPath` issues with Podman.
- Harbor `harbor-log` container no longer receives logs (Podman doesn't
  support syslog log driver). Host rsyslog now reads container logs from
  journald and routes them to `/var/log/harbor/<container>.log` files.
- Centralized all component versions into `inventory/group_vars/all/main.yml`.
  Roles and group_vars now reference version variables instead of hardcoding
  tags. To bump a version, edit one file.
- Monitoring containers run on a Podman CNI network (`monitoring`) instead
  of `hostNetwork: true`. Services exposed to host via `hostPort` mappings.
- node-exporter listens on host IP (`{{ ansible_host }}:9100`) instead of
  `127.0.0.1:9100`, allowing Prometheus in the pod network to reach it via FQDN.
- Prometheus scrapes node-exporter targets using FQDN from inventory
  (`ansible01.local.lan:9100`, `ansible02.local.lan:9100`) with mTLS.
- Prometheus self-scrape uses `metrics_path: /prometheus/metrics` (required
  with `--web.route-prefix=/prometheus/`).
- mTLS client cert/key permissions set to `0644` for container access
  (Prometheus runs as uid 65534).
- Renamed `playbooks/harbor-sync-images.yml` to `sync-update-containers.yml`.
- Extracted sync logic from playbook into `harbor_containers` role.
- `harbor_config` now creates projects from `harbor_sync_images` when
  `harbor_config_sync_projects: true` (single source of truth for projects).
- Version update check only matches tags with same naming convention
  (v-prefix, part count, suffix). E.g., `v3.3.0` → `v3.13.1`, not
  `v3.13.1-distroless`.
- Podman push uses shell command instead of `podman_image` module
  (bypasses remote verification that fails for new repositories).
- Harbor service accounts use normal users instead of robot accounts
  (Harbor v2.11 robot accounts are incompatible with Podman login).
- `harbor_containers` role writes `auth.json` file directly instead of
  using `podman login` (workaround for broken login in Podman 5.8.2).
- Push command uses `--tls-verify=false` flag.
- `harbor_config` role creates project-level roles for service accounts
  (projectAdmin for config, developer for sync) instead of robot accounts.
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
- `certificates` role now uses `certificates_extra_sans` list instead of
  hardcoded `harbor_hostname`. Each group/host defines its own SANs
  (e.g., `harbor.local.lan` for harbor, `monitoring.local.lan` for monitoring).
- `versions.yml` merged into `group_vars/all/main.yml` — single file for
  all configuration and version variables.

### Removed

- Robot account tasks from `harbor_config` role (fetch, create, display).
  Robot accounts do not work with Harbor v2.11's Podman integration.
- Robot secrets from vault (replaced by normal user passwords).

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
