# AGENTS.md

Instructions for AI agents working on this Ansible infrastructure project.

## Project Overview

Infrastructure-as-code for a homelab environment managing three Rocky Linux 10 VMs:
- **ansible01** (192.168.100.10): Harbor v2.11.0 container registry
- **ansible02** (192.168.100.11): Grafana/Prometheus/Alertmanager monitoring stack + nginx reverse proxy
- **ansible03** (192.168.100.12): Elasticsearch/Logstash/Kibana (ELK) logging stack

Host OS: CachyOS (Arch-based) with libvirt 12.5.0 and Podman 5.8.2.

## Requirements

### System
- Ansible >= 2.17
- Python 3.14.6+
- Collections: `ansible.posix`, `community.crypto`, `containers.podman`
- `ansible-vault` for encrypted variables

### Environment
- VMs: Rocky Linux 10.2 (libvirt, UEFI, VirtIO)
- Network: `ansible-net` NAT (192.168.100.0/24, bridge `virbr-ansible`)
- Storage: `sdb` pool (dir-backed on `/var/lib/libvirt/sdb`, XFS, autostarted, fstab entry)
- Container runtime: Podman 5.8.2 (not Docker)

## Architecture

```
┌───────────────────────────────────────┐
│         CachyOS Host (Arch)           │
│    libvirt 12.5.0, Podman 5.8.2       │
├───────────────────────────────────────┤
│                                       │
│ ┌──────────────┐ ┌──────────────┐     │
│ │   ansible01  │ │    ansible02  │     │
│ │              │ │              │     │
│ │  Harbor v2.11│ │ Monitoring   │     │
│ │              │ │              │     │
│ │  /data/harbor│ │ Grafana 3000 │     │
│ │  storage/    │ │ Prometheus   │     │
│ └──────┬───────┘ │ Alertmanager │     │
│        │         │ node-exporter│     │
│        ▼         │ (mTLS:9100)  │     │
│  nginx :80/443   └──────────────┘     │
│  direct HTTP(80) │                     │
├─────────────────►┌──────────────┐     │
│                   │    ansible03  │     │
│                   │              │     │
│                   │   ELK Stack   │     │
│                   │              │     │
│                   │ ES:9200/9300 │     │
│                   │ Logstash     │     │
│                   │ Kibana 5601  │     │
└───────────────────┴──────────────┘     │
    ┌─────────────────────────────────┐  │
    │ Persistent storage:             │  │
    │ PV/PVC on /var/lib/elk/         │  │
    └─────────────────────────────────┘  │
```
```

Or use online services:
- https://plantuml.com/online/
- https://www.planttext.com/

All PlantUML diagrams in this document are source files — copy the code block above and save as `architecture.puml` to render.

All services run as Podman containers using `podman kube play` with K8s YAML manifests or `podman-compose`.

## Roles

| Role | Description | Deploy Target |
|------|-------------|---------------|
| `harbor` | Harbor v2.11.0 container registry (offline installer + prepare) | ansible01 |
| `monitoring` | Grafana/Prometheus/Alertmanager via ConfigMaps | ansible02 |
| `elk` | Elasticsearch/Logstash/Kibana via ConfigMaps + PVCs | ansible03 |
| `node_exporter` | Binary install, systemd service, mTLS web config | all hosts (sidecar on ELK) |
| `certificates` | Selfsigned/CA certificates with auto-renewal (≤ 30 days) | all VMs + localhost |
| `common` | Package management, protected package safety, chrony | all VMs |
| `firewall` | firewalld rules for services, UFW for libvirt host bridge | ansible02 |
| `hardening` | STIG/CIS Benchmark (toggleable modules) | all VMs |
| `nginx` | Nginx reverse proxy configuration | ansible01, ansible02 |
| `podman` | Podman setup + registries.conf | ansible03 |
| `libvirt` | VM provisioning via `community.libvirt` collection | localhost (provisioner) |

## Rules

### Code Style
1. **No comments in code** unless explicitly requested
2. **YAML**: 2-space indentation, no tabs
3. **Jinja2**: Use `| default()` filter for optional variables
4. **Vault**: Use individual `!vault |` tagged strings, not full-file encryption
5. **Module names**: Always use FQCN (e.g., `ansible.builtin.copy`, not `copy`)

### Variable Naming
- Role defaults: `rolename_variable_name` (e.g., `monitoring_grafana_password`)
- Group vars: `variable_name` (e.g., `harbor_hostname`)
- Version vars: `component_version` in `group_vars/all/main.yml`
- Vault vars: `vault_variable_name` (e.g., `vault_elasticsearch_password`)

### File Structure
```
roles/
  rolename/
    defaults/main.yml    # Default variables (lowest priority)
    tasks/main.yml       # Main task file
    handlers/main.yml    # Handler definitions
    templates/           # Jinja2 templates (.j2 extension)
    files/               # Static files
    meta/                # Role metadata and dependencies
      main.yml           # role_name: description, dependencies,
                         #   galaxy_info, software_build_commands,
                         #   full_environment_vars
```

### Molecule Testing

Each role must include molecule tests to validate idempotency and correctness:

```yaml
# roles/harbor/molecule/default/
molecule:
  dependency:
    playbooks: ../playbooks/...
  driver:
    name: podman
  scenario:
    create: true
    destroy: false
```

**Required test cases per role:**
- `default` — Validates default variable configuration, basic connectivity
- `minimum` — Tests minimal deployment with essential services only
- `full` — Full environment validation with all features enabled

**Testing workflow:**
```bash
# Run tests for specific role
cd roles/harbor && molecule test

# Test individual scenarios
cd roles/harbor && molecule scenario default test

# Create isolated test environment
cd roles/harbor && molecule converge

# Verify idempotency (second run should be clean)
cd roles/harbor && molecule idempotence
```

**Test assertions:**
- All tasks execute without errors
- Services start and pass health checks
- Configuration files are correctly generated
- Ports are properly allocated (no conflicts)
- Container images pull successfully
- PV/PVC mounts work as expected

## Container Deployment Patterns

### Harbor (ansible01) — `podman-compose`

Harbor is deployed using the offline installer + prepare approach, managed by `podman-compose`:

1. Download Harbor v2.11.0 offline installer (`harbor-offline-installer-*.tgz`)
2. Extract to `/opt/harbor`, copy files to install directory
3. Load images from `harbor.{version}.tar.gz` into Podman
4. Create data directories: database, redis, registry, storage, job_logs, ca_download, config
5. Configure `harbor.yml`: hostname, admin password, TLS cert paths, Trivy (skip_update: true in offline mode), metrics port
6. Patch `docker-compose.yml` — rewrite `goharbor/*` image references to Harbor library copies, remove Podman-incompatible logging driver
7. Run `prepare --with-trivy`, then `podman-compose up -d`

**Key difference from other services**: Harbor does NOT use `podman kube play`. It uses the offline installer + prepare + podman-compose workflow.

### Monitoring & ELK — `podman kube play`

Both monitoring and ELK stacks deploy via K8s YAML manifests using `podman kube play`:

1. Render Jinja2 templates to generate configs
2. Slurp static files for ConfigMap content
3. Write pod manifest with inline ConfigMaps + PersistentVolumes/PVCs
4. Run `podman kube play --down` then `podman kube play --network <name>`
5. Fix data directory ownership: grafana=472, prometheus/alertmanager=65534

**Configuration pattern**: All config as ConfigMaps (not hostPath mounts). PV/PVC with `ReadWriteOnce`, reclaim policy Retain.

### nginx Reverse Proxy

- Deployed on ansible01 and ansible02
- HTTPS on port 443, routes to services via sub-paths:
  - `/grafana/` → Grafana (3000)
  - `/prometheus/` → Prometheus (9090)
  - `/alertmanager/` → Alertmanager (9093)
- Bind to `127.0.0.1` via `hostIP` for internal service access

### PersistentVolumes with podman kube play

Use PV/PVC instead of hostPath for data volumes — this is the K8s-compatible pattern:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: my-app-data
spec:
  capacity:
    storage: 50Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /var/lib/elk/elasticsearch
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-app-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
```

### podman kube play — K8s Compatibility Reference

**Supported K8s kinds:** Pod, Deployment (replicas always 1), DaemonSet, Job, PersistentVolumeClaim, ConfigMap, Secret

**Supported volume types:** hostPath, emptyDir, configMap, persistentVolumeClaim, image

**Container fields supported:** name, image, ports (containerPort/hostIP/hostPort/protocol), env (value/valueFrom.*), envFrom, volumeMounts (mountPath/name/readOnly/subPath), resources (limits/requests), livenessProbe, securityContext (runAsUser/runAsGroup/readOnlyRootFilesystem/privileged/capabilities/seLinuxOptions), lifecycle.stopSignal

**Container fields NOT supported:** readinessProbe, startupProbe, tty, stdin

## Networking
- All monitoring + ELK services behind nginx reverse proxy on port 443 (HTTPS)
- Harbor directly exposed on HTTP/HTTPS (port 80/443) and metrics (port 8090)
- Use Podman CNI networks for inter-container communication: `elk` and `monitoring`
- mTLS for node-exporter scraping enforces TLS 1.3 minimum (ECDSA-P256 certs, monitoring CA, server/client certs distributed to all hosts)
- DNS entries in `ansible-net` libvirt network

## Security
- **SELinux**: Enforcing mode on all hosts
- **TLS**: 1.3 minimum — TLS 1.2 and earlier disabled (ECDHE-only key exchange, AES-256-GCM-SHA384)
- **Certificates**: Generated by `certificates` role with auto-renewal within 30 days; Harbor TLS trust configured via CA bundle (`/etc/pki/ca-trust/source/anchors/harbor.crt`); nginx enforces OCSP stapling
- **Passwords**: Vault-encrypted, never plaintext (Harbor admin: `vault_harbor_admin_password`, sync user: `vault_harbor_sync_password`, metrics: `vault_harbor_metrics_password`)
- **Hardening**: STIG/CIS Benchmark with 10 toggleable modules via `hardening_*` defaults
- **Trivy**: Harbor vulnerability scanner enabled, auto-scan on all projects (skip_update: true in offline mode)

## Playbook Development
1. **Test changes**: Run `ansible-playbook playbooks/provision-ansibleXX.yml` on appropriate host
2. **Idempotency**: Tasks must be idempotent (use `changed_when`, `when` conditions)
3. **Error handling**: Use `failed_when: false` for optional tasks, `register` for output
4. **Handlers**: Use `notify` for dependent restarts, avoid manual restarts

## Inventory Structure

```
inventory/
  hosts.yml              # Group definitions (ansible01, ansible02, ansible03)
  group_vars/all/main.yml           # Centralized versions + host entries
  group_vars/all/vault.yml          # Vault-encrypted passwords
  group_vars/<group>/main.yml       # Group-specific defaults
  group_vars/harbor/images.yml      # Image definitions with registry mappings
  host_vars/<hostname>/main.yml     # Connection, VM specs, DNS
  host_vars/<hostname>/provision.yml # Playbook-specific variables (optional)
```

## Common Patterns

### Adding a New Dashboard
1. Export JSON from Grafana UI
2. Place in `roles/monitoring/files/dashboards/`
3. Add to `monitoring_grafana_dashboards` list in defaults/main.yml
4. Re-run provisioning playbook

### Adding a New Host
1. Add to `inventory/hosts.yml` under appropriate group (ansible01, ansible02, or ansible03)
2. Create `inventory/host_vars/<hostname>/main.yml` with connection, VM specs, DNS
3. Add host entry to `controller_hosts_entries` in `group_vars/all/main.yml`
4. Add DNS entries for all services on that host
5. Update `ansible.cfg` or use appropriate inventory group

### Updating Container Images
1. Update version in `inventory/group_vars/all/main.yml`
2. Run `ansible-playbook playbooks/sync-update-containers.yml` to sync to Harbor
3. Re-run provisioning playbook for affected hosts (`provision-ansible01.yml`, etc.)

## Validation

After making changes, run:
```bash
# Syntax check
ansible-playbook playbooks/provision-ansibleXX.yml --syntax-check

# Dry run
ansible-playbook playbooks/provision-ansibleXX.yml --check

# Full deployment
ansible-playbook playbooks/provision-ansibleXX.yml
```

## Troubleshooting

### Common Issues
- **SELinux blocking**: Check `audit.log`, set booleans with `ansible.posix.seboolean`
- **Certificate errors**: Verify SANs, check expiry with `openssl x509 -noout -enddate`
- **Container permissions**: Run `chown -R UID:GID /path` for data directories
- **Podman kube play fails**: Check auth.json exists at `/root/.config/containers/auth.json`
- **Harbor push fails**: Ensure `ansible-sync` user has developer role (not maintainer)
- **Harbor compose issues**: Harbor uses podman-compose, not plain podman. Docker logging driver removed by patching.

### Debug Commands
```bash
# Check container status
podman ps -a

# View logs (monitoring stack)
podman logs <container-name> --tail 50

# Test connectivity
curl -sk https://hostname/service/health

# Harbor compose status
cd /opt/harbor && podman-compose ps

# View Harbor logs (rsyslog routed to files)
ls /var/log/harbor/
```

## References

- [LIFECYCLE.md](LIFECYCLE.md) — Version management, update procedures
- [docs/harbor.md](docs/harbor.md) — Harbor configuration
- [docs/monitoring.md](docs/monitoring.md) — Monitoring stack
- [docs/monitoring-configuration.md](docs/monitoring-configuration.md) — Monitoring configuration manual
- [docs/elasticsearch.md](docs/elasticsearch.md) — ELK stack
- [docs/elk-configuration.md](docs/elk-configuration.md) — ELK configuration manual
- [docs/hardening.md](docs/hardening.md) — Hardening modules
- [docs/vm.md](docs/vm.md) — VM lifecycle
- [docs/cloud-kvm.md](docs/cloud-kvm.md) — Cloud KVM setup
