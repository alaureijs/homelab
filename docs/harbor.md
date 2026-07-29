# Harbor

Harbor v2.11.0 container registry running on ansible01 (192.168.100.10).

## Architecture

- **Install method**: Offline installer, managed by `podman-compose`
- **Storage**: `/data/harbor` on 60 GB VirtIO disk
- **TLS**: Self-signed CA, certificates via `certificates` role
- **Trivy**: Vulnerability scanner enabled with auto-scan

## Access

```bash
# Web UI
https://harbor.homelab.internal/

# API
curl -sk -u admin:\$HARBOR_PASSWORD https://harbor.homelab.internal/api/v2.0/health
```

## Users

| Username | Role | Purpose |
|----------|------|---------|
| admin | System admin | Web UI, system management |
| ansible-config | projectAdmin | Harbor API configuration |
| ansible-sync | developer | Image push/pull |
| viewer | guest | Read-only access |
| metrics | guest | Prometheus metrics scraping |

All passwords in `inventory/group_vars/all/vault.yml`.

## Projects

- **library** — Default project, contains all synced images
- **docker-hub-cache** — Proxy cache for Docker Hub
- **quay-cache** — Proxy cache for Quay.io
- **ghcr-cache** — Proxy cache for GitHub Container Registry

## Container Images

20 images synced via proxy cache projects. Versions defined in
`inventory/group_vars/all/main.yml`, images in `inventory/group_vars/harbor/images.yml`.

```bash
# Sync images
ansible-playbook playbooks/sync-content.yml

# Check for upstream updates
ansible-playbook playbooks/sync-content.yml --check
```

## Metrics

Harbor exposes Prometheus metrics on port 8090:

```bash
# Test metrics endpoint
curl -sk -u "metrics:$VAULT_HARBOR_METRICS_PASSWORD" http://harbor.homelab.internal:8090/metrics
```

- **harbor-exporter** image: `goharbor/harbor-exporter:v2.11.0` (synced from Docker Hub)
- **elasticsearch-exporter** image: `prometheuscommunity/elasticsearch-exporter:v1.11.0` (synced from Docker Hub)
- Prometheus scrapes both endpoints via the `harbor` and `elasticsearch` jobs

## Logging

Harbor container logs are routed to `/var/log/harbor/` via host rsyslog.
Podman doesn't support the syslog log driver that Harbor expects, so we
read from journald and write to per-container files.

| File | Container |
|------|-----------|
| `harbor-core.log` | Harbor Core |
| `harbor-db.log` | PostgreSQL |
| `harbor-jobservice.log` | Job Service |
| `harbor-portal.log` | Web Portal |
| `harbor-log.log` | Log collector |
| `registry.log` | Docker Registry |
| `registryctl.log` | Registry Controller |
| `trivy-adapter.log` | Trivy Scanner |
| `redis.log` | Redis |
| `nginx.log` | Nginx Proxy |

Logrotate: daily, 14-day retention (`/etc/logrotate.d/harbor`).

## TLS Certificates

Certificates are auto-renewed within 30 days of expiry.

```bash
# Force renewal
ansible-playbook playbooks/harbor-certs.yml -e certificates_force_renewal=true

# Check expiry
openssl x509 -in /etc/pki/tls/certs/harbor.crt -noout -enddate
```

## Management Commands

```bash
# SSH
ssh root@192.168.100.10

# Check container status
podman ps

# View logs
tail -f /var/log/harbor/harbor-core.log

# Restart Harbor
cd /opt/harbor && podman-compose down && podman-compose up -d

# Harbor health
curl -sk https://harbor.homelab.internal/api/v2.0/health
```

## Updating Container Images

1. Update version in `inventory/group_vars/all/main.yml`
2. Run `ansible-playbook playbooks/sync-content.yml` to sync to Harbor
3. Re-run provisioning playbook for affected hosts (`provision-ansible01.yml`, etc.)

### sync-content.yml Requirements

**Prerequisites:**
- Harbor must be deployed and running on ansible01
- `ansible-sync` user must have developer role in Harbor
- Podman, skopeo, and python3 must be installed on ansible01

**Required Variables:**
- `harbor_hostname` — Harbor instance hostname (default: `harbor.homelab.internal`)
- `harbor_sync_images` — List of images to sync (defined in `inventory/group_vars/harbor/images.yml`)
- `vault_harbor_sync_password` — Vault-encrypted password for sync user
- `harbor_config_proxy_projects` — Registry-to-project mapping (defined in `inventory/group_vars/harbor/images.yml`)

**Project Naming Convention:**
- Remote image `prom/prometheus:tag` → Harbor project: `prom`
- Remote image `grafana/grafana:tag` → Harbor project: `grafana`
- Use the first path component of the remote image name as the Harbor project
- Project is automatically determined from image name, no need to specify in `harbor_sync_images`

## Troubleshooting

### Harbor returning 504

Containers can't resolve DNS (Podman internal DNS broken):

```bash
cd /opt/harbor && podman-compose down && podman-compose up -d
```

This often happens after sysctl changes (e.g., hardening role).

### Logs not appearing in /var/log/harbor/

Check rsyslog is running and config is valid:

```bash
rsyslogd -N1 -f /etc/rsyslog.conf
systemctl status rsyslog
ls -la /var/log/harbor/
```

### Harbor push fails

Ensure `ansible-sync` user has developer role (not maintainer).

### Harbor compose issues

Harbor uses podman-compose, not plain podman. Docker logging driver removed by patching.
