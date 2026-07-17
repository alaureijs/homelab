# AGENTS.md

Instructions for AI agents working on this Ansible infrastructure project.

## Project Overview

Infrastructure-as-code for a homelab environment managing three Rocky Linux 10 VMs:
- **ansible01** (192.168.100.10): Harbor v2.11.0 container registry
- **ansible02** (192.168.100.11): Grafana/Prometheus/Alertmanager monitoring stack
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
- Storage: `sdb` pool on `/dev/sdb` (XFS, 465 GB)
- Container runtime: Podman 5.8.2 (not Docker)

## Architecture

```
                    ┌─────────────────┐
                    │   CachyOS Host  │
                    │  (libvirt VMs)  │
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
┌───────▼───────┐    ┌───────▼───────┐    ┌───────▼───────┐
│   ansible01   │    │   ansible02   │    │   ansible03   │
│  Harbor v2.11 │    │   Monitoring  │    │     ELK       │
│  Registry     │    │  Grafana      │    │  Elasticsearch│
└───────────────┘    │  Prometheus   │    │  Logstash     │
                     │  Alertmanager │    │  Kibana       │
                     └───────────────┘    └───────────────┘
```

All services run as Podman containers using `podman kube play` with K8s YAML manifests.

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
- Version vars: `component_version` (e.g., `elasticsearch_version`) in `group_vars/all/main.yml`
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
    meta/main.yml        # Role metadata and dependencies
```

### Container Deployment
1. **Never use Docker** — Podman only
2. **Use `podman kube play`** for multi-container pods
3. **Bind to `127.0.0.1`** via `hostIP` for nginx reverse proxy
4. **Write auth.json** directly for `podman kube play` (no `--authfile` support)
5. **Fix permissions after deploy** — containers run as non-root (uid 1000, 472, 65534)
6. **Use ConfigMaps** for configuration (inline in pod manifest, not hostPath)

### Networking
- All services behind nginx reverse proxy on port 443 (HTTPS)
- Use Podman CNI networks for inter-container communication
- mTLS for node-exporter scraping (monitoring CA)
- DNS entries in `ansible-net` libvirt network

### Security
- **SELinux**: Enforcing mode on all hosts
- **Certificates**: Auto-renew within 30 days, use `certificates_extra_sans` list
- **Passwords**: Vault-encrypted, never plaintext
- **Hardening**: STIG/CIS Benchmark with 10 toggleable modules

### Playbook Development
1. **Test changes**: Run `ansible-playbook playbooks/provision-ansibleXX.yml` on appropriate host
2. **Idempotency**: Tasks must be idempotent (use `changed_when`, `when` conditions)
3. **Error handling**: Use `failed_when: false` for optional tasks, `register` for output
4. **Handlers**: Use `notify` for dependent restarts, avoid manual restarts

### Git Workflow
1. **Commit messages**: Concise, imperative mood (e.g., "Add Prometheus dashboard")
2. **No secrets**: Never commit plaintext passwords or keys
3. **Documentation**: Update README.md, CHANGELOG.md, and relevant docs/ files
4. **Push**: Only when explicitly requested

## Common Patterns

### Adding a New Dashboard
1. Export JSON from Grafana UI
2. Place in `roles/monitoring/files/dashboards/`
3. Add to `monitoring_grafana_dashboards` in defaults/main.yml
4. Re-run provisioning playbook

### Adding a New Host
1. Add to `inventory/hosts.yml` under appropriate group
2. Create `inventory/host_vars/hostname/main.yml`
3. Add DNS entry to libvirt network
4. Create provisioning playbook in `playbooks/`

### Updating Container Images
1. Update version in `inventory/group_vars/all/main.yml`
2. Run `ansible-playbook playbooks/sync-update-containers.yml`
3. Re-run provisioning playbook for affected hosts

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
- **Podman kube play fails**: Check `auth.json` exists at `/root/.config/containers/auth.json`
- **Harbor push fails**: Ensure `ansible-sync` user has developer role (not maintainer)

### Debug Commands
```bash
# Check container status
podman ps -a

# View logs
podman logs container-name

# Test connectivity
curl -sk https://hostname/service/health
```

## References

- [LIFECYCLE.md](LIFECYCLE.md) — Version management, update procedures
- [docs/harbor.md](docs/harbor.md) — Harbor configuration
- [docs/monitoring.md](docs/monitoring.md) — Monitoring stack
- [docs/elasticsearch.md](docs/elasticsearch.md) — ELK stack
- [docs/hardening.md](docs/hardening.md) — Hardening modules
- [docs/vm.md](docs/vm.md) — VM lifecycle
