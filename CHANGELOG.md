# Changelog

All notable changes to this project will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- k8s ingress: Cilium native ingress controller replaces MetalLB +
  ingress-nginx. Cilium 1.18 configured with `ingressController` (shared
  `cilium-ingress` LoadBalancer, `loadbalancerMode: shared`) and
  `l2announcements.enabled: true`; fixed VIP via `lbipam.cilium.io/ips`
  annotation (`kubernetes_cilium_ingress_vip`). `roles/kubernetes` renders
  and applies `CiliumLoadBalancerIPPool` `homelab-pool`
  (192.168.100.40-49) + `CiliumL2AnnouncementPolicy` `homelab`
  (interface `enp1s0`, all LB services) to
  `/etc/kubernetes/cilium/cilium-lb.yaml`.
- k8s apps: all ingresses flipped to `ingressClassName: cilium` — argocd,
  longhorn, monitoring (grafana `/grafana`, prometheus `/prometheus`,
  alertmanager `/alertmanager`), observability (kibana `/kibana`). Dropped
  `nginx.ingress.kubernetes.io/ssl-redirect` annotation; observability
  ES `/elasticsearch` ingress removed (no consumers — OTel collector ships
  in-cluster).
- k8s inventory: `metallb_pool` renamed to `cilium_lb_pool`; dropped
  `metallb_version` and `ingress_nginx_version` version variables.
- `Plans/Plan_CiliumLB_Ingress.md` — migration plan with cutover and
  rollback checklist.

## [0.2.0] - 2026-08-05

### Added

- k8s P8: ArgoCD namespaced apps `monitoring`/`monitoring-secrets`/`observability`
  synced and healthy; controller namespace-watch via
  `configs.params.application.namespaces` in `cluster/base/argocd/values.yaml`.
- k8s storage: Longhorn now default StorageClass; Prometheus/Alertmanager/
  Grafana/Elasticsearch PVCs migrated off local-path. DaemonSets keep local
  storage by policy (OTel collector DS uses hostPath `/var/log`).
- k8s observability: OTel collector DaemonSet ships logs to ECK Elasticsearch
  (v9.4.4) via ES exporter with mTLS; `logs-generic.otel-default` stream
  confirmed. Single-node ES green via `index.number_of_replicas: 0` +
  `otel-single-node` index template.
- `playbooks/libvirt-teardown.yml` — destructive, idempotent lab teardown:
  destroy/undefine all VMs in the `libvirt` group (UEFI NVRAM removed),
  delete qcow2/VARS/ISO artifacts and cached cloud image, undefine
  `ansible-net` + `project01` networks, and remove UFW DHCP/DNS/route rules
  for `virbr-ansible`. Refuses to run without
  `-e libvirt_teardown_confirm=true`. Documented in
  `knowledge/playbooks/libvirt-teardown.md`.
- `libvirt-teardown` also destroys/undefines the `sdb` storage pool and
  deletes `/var/lib/libvirt/sdb` (dir-backed pool holding orphaned VM
  artifacts from an earlier generation).

### Removed

- `local-path-provisioner` (Helm v0.0.36) and `local-path-storage` namespace
  from the k8s cluster — 0 local-path PVCs/PVs verified before removal;
  `local-path` StorageClass gone.
- Nextcloud/Deck references from `AGENTS.md` — ansible04 is the step-ca,
  Unbound DNS, and nginx portal/packages/docs host (no Nextcloud role was
  ever implemented).
- Filebeat client documentation from `docs/elasticsearch.md` and
  `knowledge/services/kibana.md` — OTel collector is the sole log shipping
  pipeline to Elasticsearch.
- Stale sample `roles/postgres/` role (apt/Ubuntu-based, incompatible with
  Rocky Linux targets) and its `knowledge/roles/postgres.md` concept.
- Stale mTLS references in `AGENTS.md` Networking section — superseded by
  step-ca issued certificates (`docs/pki-step-ca.md`).

### Fixed

- `firewall` role: firewalld reload task (`systemd state: reloaded`) always
  reported changed → non-idempotent. Replaced with handler notifications
  (`notify: Reload firewalld` + `flush_handlers`).
- `packages` role: `packages_exporter_info` undefined when
  `packages_exporters` is empty → minimum deployment failed. Report tasks
  now guarded / defaulted.
- `docs/vm.md` VM table missing ansible04 (192.168.100.13).
- `AGENTS.md` roles table missing `harbor_config` and `harbor_containers`.
- ansible-lint cleanup: fixed all 23 non-`var-naming` violations across
  roles — `schema[meta]` platform version in nginx, missing `mode` on ELK
  template tasks, `set -o pipefail` on shell pipes, `changed_when` on
  libvirt resize/cloud-init tasks, folded long YAML scalars, and
  `systemd`/`command` module idioms in step-ca handlers/tasks.
- MetalLB VIP `192.168.100.42` intermittent drops (30–65% failure on
  external → LB → local-backend traffic): root-caused to upstream
  cilium/cilium#44630 (silent drop of LB traffic in VXLAN tunnel mode when
  the ingress node is also the LB L2 owner). Fixed by migrating Cilium to
  native routing (`routingMode: native`, `autoDirectNodeRoutes: true`,
  `ipv4NativeRoutingCIDR: 10.0.0.0/8`) — all 4 nodes share L2
  `192.168.100.0/24`, so direct node routes suffice (no BGP). Cilium
  remains helm-managed; `helm get values` matches
  `kubernetes_cilium_values` (no drift, `--check` clean).
- `firewall` role: firewalld policy objects are the only native way to
  allow pod-CIDR forwarding (rich/direct rules cannot override the
  `filter_FORWARD_POLICIES` reject). Added `firewall_trusted_sources`,
  `firewall_trusted_interfaces`, and `firewall_forward_policies` defaults +
  idempotent `--permanent` policy shell task (`allow-pod-fwd`: ingress
  `public` → egress `trusted`, ACCEPT, priority 50). Applied to all 4 k8s
  nodes (pod CIDR `10.0.0.0/8` + `cilium_host` in trusted zone). Verified
  idempotent on second run (`changed=0`) and lint-clean.

### Added

- `knowledge/references/` — 6 new OKF Reference concepts: Knowledge
  Catalog, Ansible Style Guide, Caveman, AutoResearch, Karpathy System
  Prompt Gist, Multica Karpathy Skills; regenerated `references/index.md`
  and root `knowledge/index.md` from concept frontmatter.
- `opencode.json` LSP config for ansible-language-server (`.yml`/`.yaml`)
  and pyright (`*.py`).
- Molecule coverage for 5 roles — `common`, `podman`, `firewall`, `nginx`,
  `packages` — each with `default`/`minimum`/`full` scenarios
  (`roles/*/molecule/`) run in isolated Podman containers; all 15 green
  (syntax, converge, idempotence, verify). Fires on
  `export ANSIBLE_ALLOW_BROKEN_CONDITIONALS=1; cd roles/<role> && molecule test -s <scenario>`.
- `docs/packages.md` — documentation for the `packages` role (referenced by
  `docs/prometheus_exporters.md` but previously missing); registered as
  source in `knowledge/services/packages.md`.
- Ansible Development Tools (ADT) installed via pipx on the controller
  (`ansible-lint 26.6.0`, ansible-navigator, ansible-builder,
  ansible-creator, molecule). Verified via `ade_environment_info`.
- `docs/ansible-mcp.md` — setup guide for the Ansible Development Tools
  MCP server (`ansible-mcp`) plus additional servers registered in
  `opencode.json`: `grafana` (uvx mcp-grafana, monitoring.homelab.internal),
  `podman` (npx podman-mcp-server), `kubernetes` (npx kubernetes-mcp-server,
  inert — no cluster), `elasticsearch` (uvx elasticsearch-mcp-server →
  `192.168.100.12:9200`, security disabled), `obsidian` (uvx mcp-obsidian),
  `github` (podman run ghcr.io/github/github-mcp-server), `libvirt` (local
  clone `~/.local/share/mcp-servers/libvirt-mcp`).
  `CHANGEME-*` placeholders pending Grafana service account token, GitHub
  PAT, and Obsidian API key.
- `knowledge/guides/ansible-mcp.md` — OKF guide mirroring the MCP setup
  (registered in `knowledge/guides/index.md`).
- OpenTelemetry log collection on all 4 VMs (`roles/otel/` +
  `playbooks/provision-otel.yml`). `otelcol-contrib` v0.157.0 collector
  ships journald + file logs over mTLS to
  `https://observability.homelab.internal/elasticsearch` → Elasticsearch
  data stream `logs-generic.otel-default`. Pipeline: journald/filelog
  receivers → resourcedetection/system + batch (5s/512) → elasticsearch
  exporter (`mapping.mode: otel`). File paths per host via `otel_log_paths`
  (Harbor `/var/log/harbor/*.log`, nginx `/var/log/nginx/*.log`, ELK
  `/var/log/elk/*.log`).
- OTel collector binary synced via internal packages server —
  `otelcol-contrib_0.157.0_linux_amd64.tar.gz` added to
  `packages_exporters` in `roles/packages/defaults/main.yml`.
- `grafana.grafana` 6.1.0 collection added to `requirements.yml` +
  `collections_path = collections` in `ansible.cfg`.
- Elasticsearch ILM lifecycle for OTel logs (`roles/elasticsearch`):
  policy `otel-logs-policy` (hot rollover `max_age` 1d /
  `max_primary_shard_size` 50gb; delete after `elasticsearch_otel_retention`
  default 30d) applied via component template `logs@custom`
  (`index.lifecycle.name`).
- nginx mTLS on `/elasticsearch/` (`roles/kibana`): combined root +
  intermediate CA built to `otel-mtls-ca-combined.crt`,
  `ssl_verify_client optional` + `ssl_verify_depth 2`,
  `$ssl_client_verify` guard returning 400, `client_max_body_size 20m`.
- `otel` inventory group (all 4 hosts) + `inventory/group_vars/otel/main.yml`
  with `otel_client_certificates` (step-ca client cert in `/etc/otel-client`,
  outside the install-wiped `/etc/otel-collector`).
- `certificates_force_renewal` extra var honored per-cert in
  `roles/certificates/tasks/generate.yml` (forces renewal regardless of expiry).
- Journald retention in `common` role: `/etc/systemd/journald.conf.d/99-retention.conf`
  (`SystemMaxUse=1G`, `MaxRetentionSec=7day`) + `Restart systemd-journald` handler.
- `harbor_containers` preflight (`tasks/preflight.yml`, toggle
  `harbor_containers_preflight`): read-only Harbor API checks before sync —
  destination project exists, target project role ≥ 2, proxy cache project
  role ≥ 3 or public (project names exempt from the proxy check), with
  existence-only fallback and fail-fast assertion. Gated behind
  `and not ansible_check_mode`.
- `harbor_containers` sync password indirection: `harbor_containers_sync_password`
  defaults to `{{ vault_harbor_sync_password }}`, overridable via extra vars
  / custom credential for AAP.
- `roles/harbor_containers/docs/README.md`: role documentation covering
  read-only design, pre-provisioning checklist, variables, preflight,
  AAP usage (collections, vault, ephemeral reports, optional skopeo/become),
  and an OS compatibility matrix (EL 8.4+/EL 9/Ubuntu 24.04).
- `harbor_containers_use_proxy_cache` toggle (default `true`): with `false`
  the role pulls directly from the upstream registry (`{{ registry }}/{{ name }}:{{ tag }}`)
  instead of through Harbor proxy-cache projects, enabling use against
  Harbor instances without proxy-cache projects. Push target and destination
  project unchanged; proxy-cache preflight checks skipped in direct mode.
- OKF v0.2 knowledge wiki at `knowledge/` (63 concepts: VMs, network,
  storage, services, playbooks, roles, operations, guides, references).
  Concepts carry `sources`/`generated`/`verified` frontmatter, per-claim
  footnotes, and bundle-relative cross-links. `scripts/okf.py` provides
  `check` (conformance: frontmatter parse, `type` required, reserved-name
  structure, warn-only broken links) and `index --write` (index.md
  generation). Vault opens as an Obsidian vault with committed `.obsidian/`
  config (markdown link format). Enforced via AGENTS.md "Knowledge Wiki"
  section; `knowledge/index.md` added to opencode instructions.

### Changed

- `harbor_containers` no longer requires `gather_facts`: `ansible_date_time`
  replaced with `'%Y-%m-%d' | strftime` (controller time) in the four report
  paths. Role runs with `gather_facts: false`; `become` optional (no
  root-required tasks; rootless needs subuid/subgid + `fuse-overlayfs`).
- `harbor_containers` Galaxy schema: Ubuntu `"24.04"` rejected by galaxy —
  platforms list uses `"all"` for Ubuntu; adds EL 8.4+ / EL 9 / EL 10 +
  Ubuntu 24.04 compatibility, `galaxy_tags: readonly`.
- `harbor_containers` defaults reflowed: sync password indirection and
  preflight vars moved into `defaults/main.yml`; `harbor_containers_preflight`
  off by default (proxy-cache model and naming convention unchanged).

- Logrotate for Harbor and ELK log dirs centralized in `common` role via
  `common_logrotate_configs` (rotate 7, daily, copytruncate). Per-role
  logrotate blocks removed from `harbor`, `elasticsearch`, `logstash`, `kibana`.
- `provision-common.yml` pre_task now merges `otel_client_certificates`
  into the certificates list (Ansible replaces lists across groups, so
  `portal`'s `certificates_extra` clobbered `otel`'s on ansible04).
- `site.yml` restructured to run common roles exactly once on all hosts.
  App-specific plays split into `provision-ansible0X-app.yml`; each
  `provision-ansible0X.yml` wrapper stays self-contained (imports
  `provision-common.yml` + its `-app` playbook). `site.yml` now imports
  common once, then `provision-ansible04-app` → `provision-ansible01-app`
  → `sync-content` → `provision-ansible02-app` → `provision-ansible03-app`
  → `provision-otel.yml` (newly included). Previously common roles ran
  4× on every host per `site.yml` run.

### Fixed

- SAN derivation `regex_replace` replacement `'DNS:\\1'` → `'DNS:\1'` in
  `playbooks/provision-common.yml` and `playbooks/harbor-certs.yml`. The
  double backslash emitted literal `DNS:1` SANs — all host certs were
  regenerated with broken SANs (`DNS:ansible0X, DNS:1, DNS:1`, service
  FQDNs missing). After fix host certs carry correct FQDNs
  (e.g. ansible03: `observability.homelab.internal`).
- nginx `ssl_verify_client` is not allowed inside `location` context
  (nginx 1.26.3). Moved to server level with `optional`, enforced in the
  `/elasticsearch/` location via `if ($ssl_client_verify != SUCCESS) { return 400; }`.

### Changed

- `elasticsearch_heap_size` reduced 4g → 2g (`inventory/group_vars/elk/main.yml`)
  and pod manifest resources lowered (limits 5Gi → 4Gi, requests 4Gi → 3Gi).
  ES (`-Xmx4g` + 2 GB direct memory) plus Logstash (2g heap) exceeded the
  8 GB ansible03 VM with no swap, so the OOM killer repeatedly killed the
  ES JVM and the restart loop pinned CPU at 100%.
- ELK restart handlers (`elasticsearch`, `logstash`, `kibana`) now use
  `podman kube play --network host` — previously used `--network {{ elk_network_name }}`
  (bridge `elk` network), which dropped host port bindings on config-driven
  restarts and caused nginx 502s. Tasks already used host network mode;
  handlers now match.
- ELK networking documented as host network mode (`--network host`) in
  `docs/elasticsearch.md`, `docs/elk-configuration.md`,
  `docs/container-deployment.md`, and AGENTS.md. `elk_network_name` marked
  legacy (network no longer used by pods).
- Portal refactored: `inventory/group_vars/portal/` created with
  `nginx_vhosts`, `nginx_directories`, and `certificates_extra`
  definitions. `nginx_vhosts` is a structured list with feature
  flags (acme_challenge, ca_alias, acme_proxy, autoindex).
- `roles/nginx/` stripped to generic installer — reads `nginx_vhosts`
  and `nginx_directories` from group_vars, deploys vhost configs from
  single `vhost.conf.j2` template (3 separate templates removed).
- `portal.conf.j2` split — `packages.homelab.internal` has its own
  vhost, each vhost gets its own step-ca certificate.
- `roles/step-ca/` now copies root CA cert to `{{ portal_web_root }}/ca/`.
- `playbooks/provision-ansible04.yml` — cert issuance + root CA deploy
  removed from post_tasks (handled by `certificates` role and `step-ca`
  role). Post_tasks now only deploy landing pages.
- `portal` role removed entirely. vhost config (`portal.conf.j2`),
  SSL paths, and port defaults moved to `nginx` role. `packages`
  depends on `nginx` directly. index.html landing page template
  moved to `nginx/templates/`.
- Extracted nginx setup into `nginx` role (install, default.conf removal,
  service enable, web root dirs). `packages` depends on `nginx`.
- Absorbed `ca-portal` into `nginx` role. ca-portal removed entirely.
  CA-specific tasks (cert issuance, landing page, root CA deploy) moved
  to playbook-level post_tasks in provision-ansible04.yml after step-ca
  and portal roles.
- Created `site.yml` — full infrastructure provisioning orchestrator
  (provision-ansible04 → 01 → sync-content → 02 → 03)
- Consolidated all content sync into single `sync-content.yml` playbook.
  Removed `download-exporters.yml`, `sync-packages.yml`,
  `sync-update-containers.yml`
- Split packages role out of `provision-ansible04.yml` into standalone
  `sync-content.yml` playbook (content updates separated from VM provisioning)
- Eliminated duplicate exporter downloads: `prometheus_exporters` now only
  downloads to controller cache (`files/prometheus/exporters/`); `packages`
  role copies from cache to ansible04 instead of downloading from GitHub
  again. `packages_exporters` list removed, `prometheus_exporters` used
  as single source of truth for exporter definitions
- DNS refactor: centralized all FQDN→IP mappings into single `dns_records`
  dict in `inventory/group_vars/all/main.yml`. Everything else derived:
  - `certificates_extra_sans` derived per-host in provision-common.yml pre_tasks
  - `controller_hosts_entries` derived in Play 0 of provision-common.yml
  - `network.xml.j2` uses `dns_records` directly (replaces `dns_local_zones`
    + `vm_dns_entries` loops)
  - `vm_dns_entries` removed from `host_vars/*/main.yml`
  - `certificates_extra_sans` removed from monitoring/elk group_vars
  - `dns_local_zones` removed from `group_vars/all/main.yml`
- `prometheus_exporters` role merged into `packages` role. Exporter
  definitions moved to `roles/packages/defaults/main.yml` as
  `packages_exporters`. Tarballs downloaded directly from GitHub to
  ansible04 (no controller cache). Version checking and report
  generation moved to packages role. `roles/prometheus_exporters/`
  deleted.
- "Pinned + latest" mirror strategy: `packages` and `harbor_containers`
  roles always download the pinned version plus the latest upstream
  version (if newer). Reports capture both for manual version pin bumps.
- Harbor installer URL changed from GitHub to `packages.homelab.internal`
  (downloaded by `packages` role, consumed by `harbor` role).
- `node_exporter` role downloads directly from GitHub (was controller
  cache copy via deleted `prometheus_exporters` role).
- `harbor_containers` syncs latest upstream version to Harbor when it
  differs from the pinned version.
- nginx vhost template: fixed `item` → `vhost` in `loop_var` override
  (bug prevented nginx from reloading in sync-content.yml on ansible04).
- `packages` group added to inventory; `sync-content.yml` targets
  `hosts: packages` so group_vars/packages/ are loaded.
- Documents vhost (`documents.homelab.internal`): autoindex enabled,
  sync-reports subdirectory added to nginx_directories.
- `sync-content.yml` third play copies exporter and sync reports to
  `{{ docs_web_root }}/documents/sync-reports/` on ansible04 after
  each sync run.
- ansible01 VM RAM bumped from 2 GB to 4 GB (Harbor OOM with 11 containers).
- New files: `inventory/group_vars/packages/main.yml` (packages_files).
- `playbooks/sync-content.yml` simplified — single packages play on
  ansible04, removed prometheus_exporters play on localhost.
- `inventory/group_vars/packages/main.yml` created with `packages_files`
  for non-exporter packages (Harbor installer).
- `roles/harbor/tasks/main.yml` — Harbor installer from packages repo.
- `roles/node_exporter/tasks/main.yml` — downloads directly from GitHub.

### Changed

- `prometheus_exporters` role merged into `packages` role. Exporter
  definitions moved to `roles/packages/defaults/main.yml` as
  `packages_exporters` (was `prometheus_exporters`). Exporter tarballs
  now downloaded directly from GitHub to ansible04's packages repo
  (bypassing controller cache). Version checking and report generation
  moved to packages role. `roles/prometheus_exporters/` deleted.
- `playbooks/sync-content.yml` simplified — single play for packages
  (ansible04), removed `prometheus_exporters` play (localhost).
- `inventory/group_vars/packages/main.yml` created with `packages_files`
  list for non-exporter packages (Harbor installer).
- `roles/harbor/tasks/main.yml` — Harbor installer downloaded from
  `packages.homelab.internal` instead of GitHub.
- `roles/node_exporter/tasks/main.yml` — downloads directly from GitHub
  instead of controller cache.


### Added

- `dns_local_zones`, `dns_upstream_forwarders`, `dns_domain` variables in
  `inventory/group_vars/all/main.yml` — centralized DNS config for libvirt
  dnsmasq (was in Unbound role defaults).
- DNS role now manages libvirt network DNS directly (destroy/define/start
  on `ansible-net`) instead of running Unbound on ansible04.
- `network.xml.j2` — DNS domain, upstream forwarders, and per-host local
  zone entries added to libvirt network definition.
- `network-config.j2` — VM DNS changed to gateway only (192.168.100.1),
  search domain simplified to `lab_domain` variable.
- `prometheus_exporters` role — downloads from GitHub releases directly,
  uploads to ansible04 package server, checks upstream for latest versions.
- `provision-common.yml` — cleanup task removes stale entries from
  controller `/etc/hosts` before adding current ones.
- `docs/pki-step-ca.md` — PKI infrastructure requirements and architecture
  for step-ca (private CA), ca-portal (nginx cert distribution), and
  Unbound DNS. Covers domain migration strategy (`local.lan` →
  `homelab.internal`), certificate lifecycle, and bootstrap flow.
- `Plans/Plan_step-ca.md` — 12-phase implementation plan for step-ca,
  ca-portal, DNS roles + full PKI migration + domain migration.
  Includes dual-domain cert strategy (both domains during transition),
  per-host migration steps, rollback procedures, and file inventory.
- `opencode.json` — opencode configuration with `ansible-dev-tools` MCP
  server, project-specific instructions for all doc files.
- Low-token rules and MCP tool utilization guidelines in `AGENTS.md`.

### Changed

- Domain migration: `local.lan` → `homelab.internal` (IANA-reserved
  RFC 6761). All documentation files updated — FQDNs, URLs, hosts
  entries, DNS search domains, email addresses. Affected files:
  `AGENTS.md`, `LIFECYCLE.md`, `README.md`, `docs/*.md` (10 files).
- Documentation restructured: monitoring and ELK docs expanded with
  ConfigMap structure, resource tuning, network configuration, and
  troubleshooting sections.
- **Step 0.0 completed**: All certificates renewed with dual-domain
  SANs (`local.lan` + `homelab.internal`). Verified Harbor (200),
  Monitoring (302), ELK (302) on both domains. Fixed mTLS client cert
  on ansible02 to include FQDN SANs for Prometheus mTLS. Updated
  `certificates_extra_sans` in harbor, monitoring, elk group_vars.
  Added `extra_sans` to node-exporter cert in `all/main.yml`.

- Logstash exporter sidecar (`kuskoman/logstash-exporter:v1.9.1`)
  deployed in the Logstash pod — exposes 90+ Prometheus-format metrics
  on port 9198 (`/metrics`). Textfile collector (`logstash.sh`) now
  a one-liner `curl -sf http://localhost:9198/metrics` with fallback
  to `logstash_up 0` on failure. Env var `LOGSTASH_URL` used (not CLI
  args — v1.9.1 does not accept `--logstash.url`). Deployed only on
  `elk` group hosts via conditional `groups` field.
- Conditional textfile collector deployment — new `groups` field on
  `node_exporter_textfile_scripts` entries filters scripts by inventory
  group membership using `rejectattr`/`selectattr` with `subset` test.
  Scripts without `groups` deploy everywhere (backward compatible).
  Sudoers template and checksum tasks also filter by group.
- `node_exporter_textfile_scripts` moved from role defaults to
  `inventory/group_vars/all/main.yml`. Role defaults retains empty
  list with documented fields for reference.
- Trivy DB mirror for offline vulnerability scanning — mirrors
  `ghcr.io/aquasecurity/trivy-db:2` OCI artifact to Harbor project
  `trivy-db` via `skopeo copy`. Trivy adapter configured with
  `SCANNER_TRIVY_DB_REPOSITORY` env var to pull updates from Harbor
  instead of GitHub. `skip_update` stays `false` so Trivy fetches
  from the mirror. Controlled by `harbor_trivy_db_mirror` toggle.
- Node exporter textfile collectors — 5 collectors running as `nobody`
  via systemd timer (every 5m): `chrony.sh` (NTP metrics),
  `fstab-check.sh` (mount status), `reboot-required.sh` (reboot pending),
  `authorized-keys.sh` (SSH key audit), `container-health.sh` (Podman
  container state, CPU, memory, network I/O, block I/O). Scripts live in
  `files/node-exporter/textfile_scripts/`, deployed with SHA256 tamper
  detection. Runner verifies checksums before execution. Sudoers grants
  passwordless sudo for `chronyc`, `needs-restarting`, `test`, `grep`,
  `podman ps`, `podman stats`.
- Textfile collector systemd service and timer (`roles/node_exporter/tasks/textfile.yml`)
  — sandboxed service with `ProtectSystem=full`, `PrivateTmp=true`, and
  kernel protection hardening. **Do not** add `RestrictNamespaces=true`
  (breaks `podman stats` cgroup access). `ProtectSystem=strict` also
  avoided (breaks Podman runtime).
- Node exporter systemd hardening (`node_exporter_service_hardening`)
  — configurable dict with `ProtectSystem=full`, `ProtectHome`,
  `PrivateTmp`, `PrivateDevices`, `ProtectKernel*`, `NoNewPrivileges`,
  `RestrictNamespaces`, `LockPersonality`, `RestrictRealtime`,
  `RestrictSUIDSGID`. `MemoryDenyWriteExecute` excluded (breaks Go mmap).
- `firewall_podman_interfaces` variable in `group_vars/all/main.yml` —
  list of Podman bridge interfaces to add to firewalld trusted zone
  (defaults to `podman1`, `cni-podman0`).
- Harbor cert entry to `inventory/group_vars/harbor/main.yml` certificates
  list so the certificates role generates Harbor TLS certs.
- `harbor_config` role added to `playbooks/provision-ansible01.yml` (after
  harbor role) for Harbor API configuration (users, projects, roles).
- ELK stack versions added to `LIFECYCLE.md` version table.
- Harbor systemd service (`roles/harbor/templates/harbor.service.j2`) —
  `oneshot` + `RemainAfterExit=yes` service for autostart. Handles
  `podman-compose up -d` / `down` lifecycle.
- `prometheus_exporters` role — downloads Prometheus exporter tarballs
  from GitHub releases to `files/prometheus/exporters/`. Checks upstream
  for latest versions, generates report in `reports/`.
- `playbooks/download-exporters.yml` — standalone playbook for downloading
  exporter tarballs.
- Version variables for new exporters in `group_vars/all/main.yml`:
  `mysqld_exporter_version`, `postgres_exporter_version`,
  `nginx_exporter_version`, `logstash_exporter_version`.
- "Binaries in Git" rule in `AGENTS.md` — never commit binaries, tarballs,
  or downloaded artifacts to the repository.
- "Textfile Collectors" section in `AGENTS.md` — documents collector
  scripts, tamper detection, sudoers, and systemd sandboxing constraints.
- `playbooks/ensure-mtls-ca.yml` — centralized mTLS CA generation on
  controller. CA key vault-encrypted with `ansible-vault` in
  `files/certificates/mtls-ca.key` (git-trackable), cert in
  `files/certificates/mtls-ca.crt`. Key decrypted on controller and
  written as plaintext to all hosts at `/etc/mtls/`. Copies
  CA to all hosts before provisioning runs.
- Harbor project `kuskoman` for logstash-exporter images — created in
  `harbor_config_projects` with user roles for all Harbor users (guest
  for viewer/metrics, developer for ansible-sync, projectAdmin for
  ansible-config).

### Changed

- `/etc/hosts` management removed from `roles/common/tasks/main.yml` (2 tasks:
  add entries + remove `local.lan` entries). VMs now use libvirt DNS for
  hostname resolution instead of static hosts file.
- Controller `/etc/hosts` management moved from common role (applied on VMs)
  to `playbooks/provision-common.yml` localhost play — cleanup step removes
  stale entries before adding current ones (prevents accumulation of old IPs).
- DNS role (`roles/dns`) rewritten from Unbound server to libvirt network
  DNS management. Destroy/define/start cycle applies DNS changes to
  `ansible-net`. Removed Unbound handlers, templates, and DNSSEC logic.

- ELK stack split into three independent roles — `elasticsearch`,
  `logstash`, `kibana`. Each deploys its own pod via `podman kube play`
  with `hostIP: 127.0.0.1` + `hostPort` for inter-service communication.
  Logstash/Kibana connect to Elasticsearch via `127.0.0.1:9200` instead
  of pod-internal DNS. `group_vars/elk/main.yml` reduced to shared vars
  (paths, network, hostname). `provision-ansible03.yml` uses three
  separate plays. Old monolithic `elk` role removed.
- Node exporter now uses local tarballs (`files/prometheus/exporters/`)
  via `ansible.builtin.copy` instead of downloading from GitHub via
  `get_url`. Added `node_exporter_version_stripped` fact to strip `v`
  prefix for file path matching (e.g., `v1.12.1` → `1.12.1`).
- `elk_elasticsearch_exporter_port: 9114` moved from
  `inventory/group_vars/elk/main.yml` to `inventory/group_vars/all/main.yml`
  (used by both ELK and monitoring roles).
- Grafana env vars in monitoring pod manifest — `GF_SERVER_ROOT_URL`
  changed from `https://{{ monitoring_hostname }}/grafana/` to
  `https://{{ monitoring_hostname }}/`; `GF_SERVER_SERVE_FROM_SUB_PATH`
  changed from `true` to `false` (Grafana now serves from root).
- nginx reverse proxy (`roles/monitoring/templates/nginx-reverse-proxy.conf.j2`)
  — Grafana location changed from `/grafana/` to `/`; added
  `/alertmanager/` location for Alertmanager UI.
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
- `podman-compose` path fixed from `/usr/bin/podman-compose` to
  `/usr/local/bin/podman-compose` in Harbor handler and tasks.
- Libvirt storage simplified — removed `sdb` storage pool management
  (define, start, autostart) from `roles/libvirt/tasks/main.yml`. VMs
  now use default `/var/lib/libvirt/images` directory. Removed
  `storage-pool.xml.j2` template.
- `libvirt_storage_pool_path` renamed to `libvirt_storage_path` (no longer
  pool-specific). References updated in `roles/libvirt/templates/vm.xml.j2`.
- Container versions updated to latest: Grafana `13.1.1`, Prometheus
  `v3.13.1`, Alertmanager `v0.33.1`, Elasticsearch/Logstash/Kibana
  `9.4.4`, Alpine `3.24`, Busybox `1.38`, Nginx `1.31-alpine`,
  Redis `8.8-alpine`, MariaDB `12.3`, Python `3.14-slim`,
  Golang `1.26-alpine`, Pushgateway `v1.11.3`.
- `node_exporter_version` fixed with `v` prefix: `1.12.1` → `v1.12.1`
  (matches quay.io tag convention).
- `AGENTS.md` updated — vault inline encryption documentation with
  correct/incorrect examples; `sync-update-containers.yml` prerequisites,
  required variables, and project naming convention added.
- Hardening SSH configuration refactored — module toggle renamed from
  `hardening_ssh` to `hardening_ssh_enabled`. All SSH settings consolidated
  into single `hardening_ssh` dict (port, protocol, crypto, access control,
  banner) in `roles/hardening/defaults/main.yml`.
- Reports directory moved from `playbooks/reports/` to project root
  `reports/`. Added to `.gitignore`.
- `harbor_containers` role — removed `images.yml` generation task and
  `images.yml.j2` template. Sync report is now the only output.
- `harbor_containers_local_report_dir` changed from `reports` to
  `../reports` (resolves to project root via `{{ playbook_dir }}/../reports`).
- `.gitignore` updated — added `reports/` and
  `files/prometheus/exporters/` to prevent committing generated files
  and downloaded binaries.
- mTLS CA architecture redesigned — single shared CA (`mtls-ca`) generated
  on controller, vault-encrypted key in `files/certificates/mtls-ca.key`
  (git-trackable), plain cert in `files/certificates/mtls-ca.crt`.
  Removed `mtls-ca` entry from `certificates` list in `all/main.yml`.
  Added `mtls_controller_cert` variable for controller path. All
  provisioning playbooks now import `ensure-mtls-ca.yml` before main
  provisioning play.
- Monitoring role no longer distributes mTLS CA to hosts — only builds
  combined CA from all hosts' local copies for Prometheus scrape config.
  Removed "Distribute combined mTLS CA to all hosts" task.
- Node-exporter server cert signed by shared mTLS CA (not separate CA).
  Certificates role generates `node-exporter.crt` using `ownca` type
  with `mtls_ca_cert`/`mtls_ca_key` paths.
- `elasticsearch_http_port: 9200` moved from role defaults to shared
  `inventory/group_vars/elk/main.yml` — used by both logstash pipeline
  output and kibana connection (single source of truth for ELK).

### Fixed

- DNS role — `virt_net define` on an active libvirt network silently accepts
  the XML but does not apply changes. Changed to destroy/define/start
  sequence in `roles/dns/tasks/main.yml` to ensure DNS entries are applied.
- libvirt network bridge recreation (`virbr-ansible` destroy/define/start)
  orphaned VM tap interfaces, making VMs unreachable. ansible03 required
  manual restart to reattach its tap interface.
- mTLS directory permissions — certificate role was creating cert
  directories with `0700`, blocking container access. Changed to `0755`
  in `roles/certificates/tasks/generate.yml`. Added fix tasks in
  `node_exporter` role (`/etc/node-exporter/` → `0750 root:node_exporter`)
  and `monitoring` role (`/etc/prometheus/mtls/` → `0755 root:root`).
  `/etc/mtls/` on all hosts set to `0750 root:node_exporter` for
  node_exporter CA cert access.
- Monitoring and ELK container image paths — all had extra path segments
  that didn't match Harbor's `project/short_name` convention. Fixed
  `grafana/grafana/grafana` → `grafana/grafana`,
  `prometheus/prometheus/prometheus` → `prometheus/prometheus`,
  `prometheus/prometheus/alertmanager` → `prometheus/alertmanager`,
  `library/library/elasticsearch` → `library/elasticsearch` (and
  logstash, kibana).
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
- Textfile runner `.prom` file permissions — `mktemp` creates files with
  `0600`, but `node_exporter` (running as user `node_exporter`) needs
  read access. Added `chmod 0644` after `mv` in the runner script.

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
