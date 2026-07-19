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
7. **Keep pod manifests K8s-compatible** — prepare for potential Kubernetes migration

### ConfigMaps with podman kube play

`podman kube play` supports ConfigMaps defined inline in the pod manifest. This is the preferred pattern for configuration.

**K8s Compatibility:**
- Use standard Kubernetes API versions (`v1`)
- Use standard resource types (`Pod`, `ConfigMap`, `Service`, `Deployment`)
- Avoid Podman-specific extensions when possible
- Use `hostPath` only when necessary (prefer ConfigMaps for config)
- Use `subPath` for mounting individual files from ConfigMaps

**Known Podman-specific features (K8s migration notes):**
- `hostIP` on `containerPort` — not supported in K8s; replace with `NetworkPolicy` or `Service` bindings
- `hostPort` — supported but not recommended for production; use `Service` + `Ingress` instead
- Podman CNI network (`--network`) — replace with K8s `NetworkPolicy`

**Structure:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-config
  labels:
    app: my-app
data:
  config.yml: |
    key: value
---
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  containers:
    - name: my-app
      volumeMounts:
        - name: config
          mountPath: /etc/app/config.yml
          subPath: config.yml
  volumes:
    - name: config
      configMap:
        name: my-config
```

**Pattern in Ansible roles:**
1. Define config file location variables in `defaults/main.yml`:
   ```yaml
   myapp_config_template: "{{ role_path }}/templates/config.yml.j2"
   myapp_rules_file: "{{ role_path }}/files/rules.yml"
   ```

2. Tasks read files and render templates before pod creation:
   ```yaml
   - name: Render config
     ansible.builtin.template:
       src: "{{ myapp_config_template }}"
       dest: /tmp/myapp-config.yml

   - name: Read config
     ansible.builtin.slurp:
       src: /tmp/myapp-config.yml
     register: myapp_config
   ```

3. Pod template uses variables for ConfigMap content:
   ```yaml
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: myapp-config
   data:
     config.yml: |
   {{ myapp_config.content | b64decode | indent(4) }}
   ```

**Benefits:**
- Configuration managed as code (no hostPath mounts)
- Changes tracked in version control
- Users can override file locations without modifying role
- Single pod manifest file contains all resources

### PersistentVolumes with podman kube play

`podman kube play` supports PersistentVolumeClaims defined inline in the pod manifest. Use PV/PVC instead of `hostPath` for data volumes — this is the K8s-compatible pattern.

**Structure:**
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: my-app-data
  labels:
    app: my-app
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /var/lib/my-app
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-app-data
  labels:
    app: my-app
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
  labels:
    app: my-app
spec:
  containers:
    - name: my-app
      volumeMounts:
        - name: data
          mountPath: /var/lib/my-app
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: my-app-data
```

**K8s Migration:**
- PV/PVC is the standard K8s pattern for persistent storage
- `persistentVolumeReclaimPolicy: Retain` — data survives PV deletion
- `accessModes: ReadWriteOnce` — single-node only (matches Podman model)
- In K8s, replace `hostPath` PV with a real provisioner (NFS, Ceph, etc.)
- PV/PVC names must match between PV, PVC, and pod volume reference

### podman kube play — K8s Compatibility Reference

Full reference of supported K8s features in `podman kube play` (Podman 5.8.2).

**Supported K8s kinds:**
| Kind | Support |
|------|---------|
| Pod | ✅ |
| Deployment | ✅ (replicas always 1, no rolling updates) |
| DaemonSet | ✅ |
| Job | ✅ |
| PersistentVolumeClaim | ✅ |
| ConfigMap | ✅ |
| Secret | ✅ |

**Supported volume types:**
| Type | Notes |
|------|-------|
| `hostPath` | `DirectoryOrCreate`, `Directory`, `FileOrCreate`, `File`, `Socket`, `CharDevice`, `BlockDevice` |
| `emptyDir` | Anonymous, deleted with pod |
| `configMap` | Anonymous, deleted with pod |
| `persistentVolumeClaim` | Creates Podman named volume |
| `image` | Read-only, rootful only |

**Pod fields:**
| Field | Support |
|-------|---------|
| `containers` | ✅ |
| `initContainers` | ✅ (default type `once`, use annotation `io.podman.annotations.init.container.type=always`) |
| `volumes` | ✅ |
| `restartPolicy` | ✅ (default: `always`) |
| `terminationGracePeriodSeconds` | ✅ |
| `hostname` | ✅ |
| `hostAliases` | ✅ |
| `dnsConfig` (nameservers, options, searches) | ✅ |
| `hostNetwork` | ✅ |
| `hostPID` | ✅ |
| `hostIPC` | ✅ |
| `shareProcessNamespace` | ✅ |
| `securityContext` (runAsUser, runAsGroup, supplementalGroups, seLinuxOptions, sysctls) | ✅ |
| `nodeSelector`, `nodeName`, `affinity`, `tolerations` | N/A (single-node) |
| `imagePullSecrets` | no |
| `serviceAccountName` | no |

**Container fields:**
| Field | Support |
|-------|---------|
| `name`, `image`, `imagePullPolicy` | ✅ |
| `command`, `args`, `workingDir` | ✅ |
| `ports` (containerPort, hostIP, hostPort, protocol) | ✅ |
| `env` (value, valueFrom.configMapKeyRef, valueFrom.secretKeyRef, valueFrom.fieldRef, valueFrom.resourceFieldRef) | ✅ |
| `envFrom` (configMapRef, secretRef) | ✅ |
| `volumeMounts` (mountPath, name, readOnly, subPath) | ✅ |
| `resources` (limits, requests) | ✅ |
| `livenessProbe` | ✅ |
| `readinessProbe` | no |
| `startupProbe` | no |
| `securityContext` (runAsUser, runAsGroup, readOnlyRootFilesystem, privileged, allowPrivilegeEscalation, capabilities, seLinuxOptions) | ✅ |
| `lifecycle.stopSignal` | ✅ |
| `tty`, `stdin` | no |

**Deployment fields:** `replicas` (ignored, always 1), `selector`, `template` ✅; `strategy`, `revisionHistoryLimit` no.

**DaemonSet fields:** `selector`, `template` ✅; `strategy` no.

**Job fields:** `template` ✅; `backoffLimit`, `parallelism`, `completions` no.

**PVC fields:** `storageClassName`, `accessModes`, `resources.requests` ✅.

**ConfigMap fields:** `binaryData`, `data` ✅; `immutable` no.

**Secret:** Supported — creates Podman named secret. Referenced via `env.valueFrom.secretKeyRef` or `envFrom.secretRef`.

**Podman-specific annotations:**
| Annotation | Purpose |
|------------|---------|
| `io.podman.annotations.userns` | User namespace mode (`keep-id`, `auto`, etc.) |
| `io.podman.annotations.volumes-from/$ctr` | Bind mount volumes from another container |
| `io.podman.annotations.init.container.type` | Init container type (`once` or `always`) |
| `io.podman.annotations.infra.name` | Custom infra container name |
| `io.podman.annotations.pids-limit/$ctr` | Per-container pids limit |
| `io.podman.annotations.cpuset/$ctr` | CPU core affinity |
| `io.podman.annotations.memory-nodes/$ctr` | NUMA memory node affinity |

**K8s migration notes:**
- `hostIP` on containerPort — not in K8s; use `NetworkPolicy` or `Service`
- `hostPort` — works but not recommended for production; use `Service` + `Ingress`
- Podman CNI `--network` — replace with K8s `NetworkPolicy`
- Deployment replicas always 1 — no real replica management
- No rolling updates, no HPA, no PDB
- `readinessProbe`/`startupProbe` not supported — use `livenessProbe` only

### Networking
- All services behind nginx reverse proxy on port 443 (HTTPS)
- Use Podman CNI networks for inter-container communication
- mTLS for node-exporter scraping (monitoring CA)
- DNS entries in `ansible-net` libvirt network

### Security
- **SELinux**: Enforcing mode on all hosts
- **Certificates**: All TLS certificates must be generated by the `certificates` role — no other role should create its own certs; use `certificates_extra_sans` list and auto-renew within 30 days
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
- [docs/monitoring-configuration.md](docs/monitoring-configuration.md) — Monitoring configuration manual
- [docs/elasticsearch.md](docs/elasticsearch.md) — ELK stack
- [docs/elk-configuration.md](docs/elk-configuration.md) — ELK configuration manual
- [docs/hardening.md](docs/hardening.md) — Hardening modules
- [docs/vm.md](docs/vm.md) — VM lifecycle
