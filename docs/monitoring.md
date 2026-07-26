# Monitoring Stack

Monitoring stack on ansible02 (192.168.100.11), accessed via `monitoring.homelab.internal`.

## Architecture

- Deployed via `podman kube play` with K8s YAML manifest
- Podman CNI network (`monitoring`) for container networking
- nginx reverse proxy on port 443 (HTTPS) with TLS
- Prometheus scrapes node-exporter via FQDN with mTLS
- All configuration via Kubernetes ConfigMaps (inline in pod manifest)

## Services

| Service | Image (from Harbor) | Port |
|---------|---------------------|------|
| Grafana | library/grafana/grafana | 3000 |
| Prometheus | prometheus/prometheus/prometheus | 9090 |
| Alertmanager | prometheus/prometheus/alertmanager | 9093 |
| Node Exporter | prometheus/prometheus/node-exporter | 9100 |

All ports bound to `127.0.0.1` via `hostPort` for nginx access only.

## Access

```bash
# Grafana
https://monitoring.homelab.internal/grafana/
# admin / \$GRAFANA_PASSWORD

# Prometheus
https://monitoring.homelab.internal/prometheus/
```

## Grafana Dashboards

Dashboards are provisioned via ConfigMaps defined in `defaults/main.yml`. To add a new dashboard:

1. Export dashboard JSON from Grafana UI (Share → Export → Save to file)
2. Place JSON file in `roles/monitoring/files/dashboards/`
3. Add to `roles/monitoring/defaults/main.yml`:

```yaml
monitoring_grafana_dashboards:
  - name: node-exporter
    file: "{{ role_path }}/files/dashboards/node-exporter.json"
  - name: prometheus
    file: "{{ role_path }}/files/dashboards/prometheus.json"
  - name: my-new-dashboard
    file: "{{ role_path }}/files/dashboards/my-new-dashboard.json"
```

4. Re-run provisioning:

```bash
ansible-playbook playbooks/provision-ansible02.yml
```

Dashboards are auto-refreshed every 30 seconds from ConfigMap volumes.

### ConfigMap Structure

All ConfigMaps are defined in `defaults/main.yml` via `monitoring_configmaps`:

```yaml
monitoring_configmaps:
  - name: "{{ monitoring_pod_name }}-datasources"
    file: "{{ role_path }}/files/grafana/datasources.yml"
  - name: "{{ monitoring_pod_name }}-prometheus"
    template: "{{ role_path }}/templates/prometheus.yml.j2"
```

- Use `file` for static content
- Use `template` for Jinja2 templates

### ConfigMap Files

- `files/grafana/datasources.yml` — Grafana datasource config
- `files/grafana/dashboards-provider.yml` — Dashboard provisioning provider
- `files/prometheus/rules.yml` — Alert rules
- `templates/prometheus.yml.j2` — Prometheus scrape config (templated)
- `templates/alertmanager.yml.j2` — Alertmanager config (templated)

### Default Dashboards

- **Node Exporter**: CPU, Memory, Disk, Network traffic panels
- **Prometheus**: Targets up, TSDB size, scrape samples, scrape duration
- **Harbor**: Request Rate, Request Duration p95, Project Count, Artifact Pull Rate
- **Elasticsearch**: Cluster Health gauge, Node Heap Usage, Active Shards, Index Docs Count

### Default Alert Rules

- **HighCPUUsage**: CPU > 80% for 5 minutes (warning)
- **HighMemoryUsage**: Memory > 80% for 5 minutes (warning)
- **HighDiskUsage**: Disk > 85% for 5 minutes (warning)
- **NodeDown**: Node unreachable for 1 minute (critical)
- **HarborHighLatency**: Request p95 > 2s (warning)
- **HarborPushFailure**: 5xx on push (critical)
- **HarborDown**: Harbor metrics unreachable (critical)
- **ClusterRed**: Elasticsearch cluster red (critical)
- **ClusterYellow**: Elasticsearch cluster yellow (warning)
- **HighHeap**: Elasticsearch heap > 80% (warning)
- **ElasticsearchDown**: Exporter unreachable (critical)

## mTLS

Node-exporter scraping uses mutual TLS:

- **CA**: `/etc/prometheus/mtls/ca.crt` (on both hosts)
- **Server cert**: `/etc/pki/tls/certs/node-exporter.crt` (per host)
- **Client cert/key**: `/etc/prometheus/mtls/client.{crt,key}` (Prometheus)

Prometheus scrapes:
- `ansible01.homelab.internal:9100` (Harbor host)
- `ansible02.homelab.internal:9100` (monitoring host)
- `harbor.homelab.internal:8090` (Harbor metrics, basic auth)
- `ansible03.homelab.internal:9114` (Elasticsearch exporter)

## Certificate Renewal

Auto-renewed within 30 days. CA renewal cascades to server/client certs.

```bash
# Force renewal
ansible-playbook playbooks/provision-ansible02.yml -e monitoring_cert_force_renewal=true

# Check expiry
openssl x509 -in /etc/prometheus/mtls/ca.crt -noout -enddate
openssl x509 -in /etc/prometheus/mtls/client.crt -noout -enddate
```

### mTLS directory access

Containers run as non-root (uid 65534/nobody); mTLS directories must be `0755` and files `0644` for read access. SELinux label `container_file_t` required. Run `chcon -R -t container_file_t /etc/prometheus/mtls/` after permission changes.

## SELinux Booleans

| Boolean | State | Purpose |
|---------|-------|---------|
| `httpd_can_network_connect` | on | nginx can connect to pod ports |
| `httpd_can_network_relay` | on | nginx relay capability |

## Management

```bash
# SSH
ssh root@192.168.100.11

# Check containers
podman ps

# Restart monitoring stack
podman kube play --down /opt/monitoring/monitoring-pod.yml && \
podman kube play /opt/monitoring/monitoring-pod.yml

# View Prometheus targets
curl -sk https://monitoring.homelab.internal/prometheus/api/v1/targets | \
  python3 -c "import sys,json; [print(f\"{t['labels'].get('job','?')}: {t['health']}\") for t in json.load(sys.stdin)['data']['activeTargets']]"
```

## Textfile Collectors

Node exporter textfile collectors run as `nobody` via a systemd timer (every 5m). Scripts live in `files/node-exporter/textfile_scripts/` and are deployed to `/usr/local/lib/node-exporter-textfile-scripts/`. Output goes to `/var/lib/node-exporter/textfiles_metrics/`.

**Collectors:**
- `chrony.sh` — NTP offset, frequency, stratum, leap status (via `sudo chronyc`)
- `fstab-check.sh` — filesystem mount status from `findmnt`
- `reboot-required.sh` — reboot pending status (via `sudo needs-restarting`)
- `authorized-keys.sh` — count of non-comment lines in each user's `authorized_keys` (via `sudo`)
- `container-health.sh` — container state, health, CPU, memory, network I/O, block I/O (via `sudo podman ps/stats`)
- `logstash.sh` — queries `logstash-exporter` sidecar on port 9198 (`/metrics`), outputs Prometheus-format metrics (only on `elk` group hosts)

**Conditional deployment:** Scripts with a `groups` field only deploy to hosts in those inventory groups. Scripts without `groups` deploy to all hosts. The `node_exporter_textfile_scripts` variable is defined in `inventory/group_vars/all/main.yml` with documented fields (`name`, `src`, `sudoers`, `groups`).

**Tamper detection:** SHA256 checksums in `.checksums` file. Runner verifies before execution.

**Sudoers:** `/etc/sudoers.d/node-exporter-textfile` grants `nobody` passwordless sudo for `chronyc`, `needs-restarting`, `test`, `grep`, `podman ps`, `podman stats`. Rules are embedded in each `node_exporter_textfile_scripts` entry as `sudoers` lists.

**Systemd sandboxing:**

- **node-exporter** service (`node_exporter_service_hardening`):
  `ProtectSystem=full`, `ProtectHome=true`, `PrivateTmp=true`,
  `PrivateDevices=true`, `ProtectKernelTunables=true`,
  `ProtectKernelModules=true`, `ProtectControlGroups=true`,
  `NoNewPrivileges=true`, `RestrictNamespaces=true`,
  `LockPersonality=true`, `RestrictRealtime=true`,
  `RestrictSUIDSGID=true`.
  Do **NOT** add `MemoryDenyWriteExecute=true` — Go binaries use mmap with execute, which will crash node_exporter.

- **node-exporter-textfile** service (`node_exporter_textfile_service_hardening`):
  `ProtectSystem=full`, `PrivateTmp=true`, `ProtectKernelTunables=true`,
  `ProtectKernelModules=true`, `ProtectControlGroups=true`,
  `RestrictSUIDSGID=true`, `RestrictRealtime=true`,
  `LockPersonality=true`.
  Do **NOT** add `RestrictNamespaces=true` — it prevents `podman stats`
  from accessing container cgroup namespaces, causing empty output.
  `ProtectSystem=strict` must also be avoided as it makes the entire
  filesystem read-only, breaking Podman runtime access even with
  `ReadWritePaths`.

## Troubleshooting

### Cockpit conflict

Cockpit uses port 9090, conflicting with Prometheus. It's auto-disabled
by the monitoring role:

```bash
systemctl disable --now cockpit.socket cockpit.service
```

### nginx showing default page

Browser DNS-over-HTTPS bypasses `/etc/hosts`. Disable DoH:
- Firefox: `about:preferences#general` → DNS over HTTPS
- Chrome: `chrome://settings/security` → Use secure DNS
- Floorp: `about:config` → `network.trr.mode` → `0`

### Node Exporter not scraping

```bash
# Verify listening on host IP
ss -tlnp | grep 9100

# Test mTLS from monitoring host
curl -s --cacert /etc/pki/tls/certs/monitoring-ca.crt \
  --cert /etc/prometheus/mtls/client.crt \
  --key /etc/prometheus/mtls/client.key \
  https://ansible01.homelab.internal:9100/metrics | head -2
```
