# Changelog

All notable changes to this project will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- `firewall_podman_interfaces` variable in `group_vars/all/main.yml` —
  list of Podman bridge interfaces to add to firewalld trusted zone
  (defaults to `podman1`, `cni-podman0`).
- Harbor cert entry to `inventory/group_vars/harbor/main.yml` certificates
  list so the certificates role generates Harbor TLS certs.
- `harbor_config` role added to `playbooks/provision-ansible01.yml` (after
  harbor role) for Harbor API configuration (users, projects, roles).
- `elk_elasticsearch_exporter_port: 9114` added to
  `inventory/group_vars/all/main.yml`.
- ELK stack versions added to `LIFECYCLE.md` version table.

### Changed

- Harbor handler (`roles/harbor/handlers/main.yml`) — ensures
  `common/config` subdirectories exist before `prepare`, strips
  unsupported syslog logging driver from generated `docker-compose.yml`,
  uses `down` + `up -d` instead of `restart` (to pick up env file changes
  from `prepare`).
- Harbor tasks (`roles/harbor/tasks/main.yml`) — always runs
  `podman-compose down` + `podman-compose up -d` after `prepare` (not
  `restart`) since `prepare` regenerates htpasswd credentials and env files
  that `restart` doesn't reload. Strips syslog logging driver from
  `docker-compose.yml` after `prepare` (Podman doesn't support it).
- Monitoring pod manifest (`roles/monitoring/templates/monitoring-pod.yml.j2`)
  — Prometheus and Alertmanager liveness probes changed from `httpGet` to
  exec-based `wget` probes. Podman 5.8.2 httpGet probes fail silently for
  some containers despite endpoints being healthy.
- ELK pod manifest (`roles/elk/templates/elk-pod.yml.j2`) —
  elasticsearch-exporter liveness probe changed from `httpGet` to
  exec-based `wget` probe (same Podman httpGet issue).
- Harbor config role (`roles/harbor_config/tasks/main.yml`) — added health
  check waits after user/project creation, re-fetches registries after
  creation, rebuilds registry map after creation.
- Firewall role (`roles/firewall/tasks/main.yml`) — added task to add
  Podman bridge interfaces to firewalld trusted zone using
  `firewall_podman_interfaces` variable.
- `elasticsearch-exporter` image source changed from
  `ghcr.io/prom/elasticsearch-exporter` (returns 403) to
  `docker.io/prometheuscommunity/elasticsearch-exporter:v1.11.0`.

### Fixed

- Vault regenerated with new password — 13 encrypted variables for all
  services (Harbor admin, sync user, metrics, ELK passwords).
- `chrony` service name corrected to `chronyd` in `roles/common/tasks/main.yml`
  (Rocky Linux 10 uses `chronyd`, not `chrony`).
- `firewalld` task: changed `immediate: true` to `immediate: false` in
  `roles/firewall/tasks/main.yml` (immediate reload causes race conditions
  with subsequent firewall tasks).
- Certificate role (`roles/certificates/tasks/generate.yml`) — added
  `file` task to ensure `_cert_dir` and `_cert_key_dir` directories exist
  before certificate generation (previously failed with "Destination
  directory does not exist").
- ELK `elk_config_dir` (`/etc/elk`) not created — added `{{ elk_config_dir }}`
  to the directory creation loop in `roles/elk/tasks/main.yml`.
- ELK image paths wrong — Harbor stores images at `library/library/*` (due
  to sync name `library/x` + project `library`); fixed
  `inventory/group_vars/elk/main.yml` to use correct double-nested paths.
- Harbor `prepare` directories — role now creates `common/config/*`
  subdirectories before running `prepare` (previously failed with missing
  directories).
- Harbor image retag — role now tags `localhost/goharbor/*` images to
  `harbor.local.lan/library/goharbor/*` before `podman-compose up -d`.
- Harbor compose patch — simplified `goharbor/*` image reference rewriting
  (removed broken `if img.startswith` logic).
- Prometheus/Alertmanager restart loop — containers were killed every ~90s
  by failing httpGet liveness probes despite endpoints being healthy;
  switched to exec-based `wget` probes.
- elasticsearch-exporter restart loop — same httpGet liveness probe issue;
  switched to exec-based `wget` probe.
- ELK log directory documentation — corrected path from `/var/log/harbor/`
  to `/var/log/elk/` in `docs/elasticsearch.md`.

## [0.1.0] - 2026-07-13

### Added

- `libvirt` role — automated VM provisioning with `community.libvirt` collection:
  - Storage pool `sdb` (dir-backed on `/var/lib/libvirt/sdb`, autostarted)
  - Network `ansible-net` (NAT via `wlan0`, bridge `virbr-ansible`, DHCP + DNS)
  - DHCP host entries with static MAC→IP mappings for all VMs
  - DNS entries for all VMs and service hostnames
  - Cloud-init provisioning (user-data/meta-data ISOs via `cloud-localds`)
  - UEFI/OVMF boot with per-VM NVRAM VARS files
  - qcow2 VM disks created from cached Rocky Linux cloud image
  - Disk resize with idempotent size comparison (`qemu-img info -U`)
  - VM definition, start, and autostart via `community.libvirt.virt`
  - UFW INPUT rules for DHCP (udp/67) and DNS (udp+tcp/53) on bridge
  - UFW route rules for guest cross-traffic and NAT forwarding
- `playbooks/libvirt.yml` — localhost playbook for libvirt VM provisioning.
- `community.libvirt >= 2.1.0` collection added to `requirements.yml`.
- `scripts/setup-sudoers.sh` — NOPASSWD sudo configuration for user.
- `libvirt` inventory group with host_vars for all three VMs.
- `docs/vm.md` — VM lifecycle documentation with automation, networking,
  storage, cloud-init, and troubleshooting sections.

### Changed

- `scripts/ufw-libvirt.sh` — replaced blanket bridge allow with specific
  INPUT rules for DHCP (udp/67) and DNS (udp+tcp/53). Route rules unchanged.
- `docs/vm.md` — expanded with automation, cloud-init, troubleshooting sections.
  Updated SSH key, storage description, and ansible03 entries.
- Storage pool type changed from device-backed (`disk`) to directory-backed
  (`dir` on `/var/lib/libvirt/sdb`) since `/dev/sdb` is not available.
- Network forward interface parameterized via `libvirt_network_forward_interface`
  (defaults to `wlan0`).

### Fixed

- Cloud-init ISOs were not regenerated when user-data templates changed due
  to `creates:` guard on the `cloud-localds` task. Removed `creates:` so
  ISOs always reflect current template content.
- SSH access broken because cloud-init `write_files` for `authorized_keys`
  and `PermitRootLogin yes` were missing. Added `write_files`, `runcmd` to
  enable root login and write SSH keys on first boot.
- Disk resize task compared against a non-existent dict key (`.virtual_size`)
  instead of parsed JSON stdout. Switched to `shell` module with inline
  `python3 -c` to extract `virtual-size` and added `qemu-img info -U` for
  shared access when VMs are running.
- Network XML template used self-referential forward interface (bridge name
  instead of physical NIC). Fixed to use `libvirt_network_forward_interface`.

### Added (previous)

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
  - ConfigMaps for all configuration (K8s-compatible pattern)
  - PersistentVolumes/PersistentVolumeClaims for data volumes
  - Liveness probes on all containers
- `observability.local.lan` DNS entry in `ansible-net` network → 192.168.100.12.
- ELK container images synced to Harbor:
  - elasticsearch:8.17.0, logstash:8.17.0, kibana:8.17.0
- elasticsearch-exporter sidecar in ELK pod (port 9114, `prom/elasticsearch-exporter:v1.11.0` from ghcr.io)
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
  - ConfigMaps for all configuration (K8s-compatible pattern)
  - PersistentVolumes/PersistentVolumeClaims for data volumes
  - Liveness probes on all containers
- `node_exporter` role — binary install, systemd service, TLS web config.
- Certificate auto-renewal — both `certificates` and `monitoring` roles
  check certificate expiry via `openssl x509 -checkend` and regenerate
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
- Container images synced to Harbor (17 images across library, prometheus):
  - Base: alpine, ubuntu, busybox
  - Application: nginx, redis, postgres, mariadb, python, node, golang
  - Monitoring: prometheus, alertmanager, grafana, node-exporter, pushgateway
  - ELK: elasticsearch, logstash, kibana
  - Exporters: elasticsearch-exporter (ghcr.io), harbor-exporter (Docker Hub)
- `meta/main.yml` for all roles with galaxy_info and dependencies.
- `.ansible-lint` configuration excluding role helper task files.
- `inventory/group_vars/harbor/images.yml` — container image definitions
  with registry, project, and proxy cache project mappings.
- `harbor_config_sync_projects` flag — auto-discovers projects from
  `harbor_sync_images` instead of requiring manual project definitions.
- Normal Harbor service accounts (`ansible-config`, `ansible-sync`, `metrics`) with
  vault-encrypted passwords for config management, image push/pull, and metrics scraping.
- Trivy vulnerability scanner enabled in Harbor with auto-scan on all
  projects.
- Harbor metrics endpoint on port 8090 with `goharbor/harbor-exporter:v2.11.0`.
- `monitoring.local.lan` DNS entry in `ansible-net` network → 192.168.100.11.
- All monitoring configuration via Kubernetes ConfigMaps:
  - `monitoring-datasources`: Grafana datasource config
  - `monitoring-dashboards-provider`: Dashboard provisioning provider
  - `monitoring-dashboard-{name}`: Individual dashboard JSON files
  - `monitoring-prometheus`: Prometheus scrape config (prometheus.yml)
  - `monitoring-prometheus-rules`: Alert rules (node-exporter.yml)
  - `monitoring-alertmanager`: Alertmanager configuration
- Default alert rules: HighCPUUsage, HighMemoryUsage, HighDiskUsage, NodeDown
- Prometheus scrape jobs for Harbor (port 8090, basic auth) and Elasticsearch (port 9114)
- Grafana dashboards for Harbor (4 panels) and Elasticsearch (4 panels)
- Alert rules for Harbor (HarborHighLatency, HarborPushFailure, HarborDown) and
  Elasticsearch (ClusterRed, ClusterYellow, HighHeap, ElasticsearchDown)
- ConfigMap structure defined in `defaults/main.yml` via `monitoring_configmaps`:
  - Use `file` for static content, `template` for Jinja2 templates
  - Config files in `files/grafana/` and `files/prometheus/`
  - Templates in `templates/` (prometheus.yml.j2, alertmanager.yml.j2)
- Config file location variables in defaults for easy customization:
  - `monitoring_prometheus_config_template`
  - `monitoring_prometheus_rules_file`
  - `monitoring_alertmanager_config_template`
  - `monitoring_grafana_datasources_file`
  - `monitoring_grafana_dashboards_provider_file`
- `common` role — package management with protected package safety:
  - `vars/el.yml` / `vars/debian.yml`: OS-specific protected package lists
  - `tasks/main.yml`: include_vars loads OS-specific list, assert blocks
    removal of protected packages, dnf install/remove, chrony
  - Managed /etc/hosts entries for all hosts on controller and VMs
- `controller_hosts_entries` in `group_vars/all/main.yml` — centralized
  /etc/hosts entries managed by both controller localhost play and common role
- `certificates` role refactored to accept `certificates` list variable:
  - `tasks/main.yml` iterates list, `tasks/generate.yml` handles selfsigned|ca|ownca
  - Monitoring mTLS cert definitions moved to `group_vars/monitoring/main.yml`
  - Base certificate definition in `group_vars/all/main.yml`
  - No more include_role calls for certificates in other roles
- `AGENTS.md` architecture updated: ansible04 added — Rocky Linux 10 VM at 192.168.100.13 running Nextcloud with Deck integration (collaborative workspace)
- `AGENTS.md` security section updated: TLS 1.3 minimum enforced on all services (nginx reverse proxy and mTLS node-exporter scraping); ECDHE-only key exchange; AES-256-GCM-SHA384 cipher suite specified as requirement

- `harbor_hostname` moved from `group_vars/harbor/main.yml` and
  `group_vars/monitoring/main.yml` to `group_vars/all/main.yml`
  (single source of truth).
- `harbor_metrics_port: 8090` added to `group_vars/all/main.yml`.
- `roles/harbor/defaults/main.yml` — removed duplicate `harbor_hostname`
  variable (now centralized in `group_vars/all/main.yml`).
- `certificates` role — fixed certificate expiry check (replaced
  `community.crypto.x509_certificate_info` with `openssl x509 -checkend`).
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
- Prometheus scrape config: Harbor metrics on HTTP port 8090 with basic auth
  and `insecure_skip_verify`.
- Harbor compose patching updated to rewrite `goharbor/*` image references
  to Harbor library copies.
- Harbor handler updated to re-run `prepare` + patching on every restart.
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
- Renamed `roles/common/vars/el.yml` to `roles/common/vars/redhat.yml`
  (matches `ansible_os_family | lower` for Rocky Linux).
- Removed `cockpit` from installed packages (port 9090 conflict with Prometheus).
- ELK pod template: added elasticsearch-exporter sidecar container
  (port 9114, hostIP 0.0.0.0, 64M-128M memory limits).

### Removed

- Robot account tasks from `harbor_config` role (fetch, create, display).
  Robot accounts do not work with Harbor v2.11's Podman integration.
- Robot secrets from vault (replaced by normal user passwords).
- `packages` variable from `group_vars/all/main.yml` (replaced by
  `common_install_packages` in common role defaults).
- Inline package install and chrony tasks from provision playbooks
  (moved to common role).

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
