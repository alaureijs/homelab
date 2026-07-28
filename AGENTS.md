Instructions for AI agents working on this Ansible infrastructure project.

#  Low-Token, MCP & Sandbox Rules

## 1. Output Style: Caveman Mode (STRICT)
- Drop preambles, fluff, politeness ("Sure, I can help").
- Drop articles (a, an, the) and auxiliary verbs when possible.
- State facts directly. Keep execution logs and comments brief.
- Preserve exact YAML syntax, Jinja2 filters, and file path names.

## 2. Input Token Conservation
- Do NOT read full files >40 lines. Use line bounds, grep, or header targets.
- Read only relevant section headers in Obsidian notes (`[[Spec#Section]]`).
- Do NOT echo full written files back into chat if already saved to disk.

## 3. Sandbox Execution Rules
- ALL playbook testing MUST run inside isolated Podman/Docker containers (`molecule test`).
- NEVER execute host-modifying CLI commands directly outside the container sandbox.

## 4. Ansible MCP Tool Utilization
- see section "OpenCode Execution Rules: Ansible Development Tools MCP"
- Prefer Ansible MCP tools (`check_syntax`, `run_playbook`, `list_inventory`) over standard shell execution where applicable.
- Pass `check_mode: true` (dry-run) via MCP when testing playbooks before applying changes.

## 5. Micro-Task Planning & State Tracking
- Breakdown tasks into the smallest atomic steps possible (`- [ ]`).
- Save execution plans to: `Plans/Plan_<Name>.md`.
- Follow every modification with a syntax check (`check_syntax`).
- If linting or syntax fails:
  - Mark task as `[FAILED]`.
  - Refactor the plan note with numbered remediation sub-tasks (e.g., 3a, 3b).
  - Fix the issue and re-test.
- On success: update checkbox to `- [x]`.

# OpenCode Execution Rules: Ansible Development Tools MCP

You are a specialized automation engineer. You must prioritize using the **Ansible Development Tools MCP Server** tools over standard bash commands, raw file writes, or generalized web searches for all Ansible-related workflows.

## 1. Explicit Tool Triggers & Restrictions

### Project Scaffolding & Setup
* **Trigger:** When starting a new project, adding collections, or building execution environments.
* **Action:** You **MUST** use the `ansible-creator` MCP tool or execution environment builder capabilities. Do not manually create folder layouts from scratch unless the MCP tool fails.

### Code Quality & Validation
* **Trigger:** Whenever editing, validating, or finalizing playbooks, roles, or task files.
* **Action:** You **MUST** run validation through the `ansible-lint` tool integration provided by the MCP server. Do not assume syntax or rely solely on internal LLM training data.

### Playbook Execution
* **Trigger:** When testing, running, or debugging an automation workflow.
* **Action:** You **MUST** execute playbooks via the MCP server's integrated execution tools. This ensures intelligent error handling and prevents broken sub-processes.
* **Restriction:** **DO NOT** execute raw `ansible-playbook` commands via the standard `bash` tool unless explicitly requested by the user.

## 2. Context & Reference Rules

* **Documentation:** For questions regarding best practices, syntax, or module capabilities, query the internal MCP Markdown resources (`guidelines://ansible-content-best-practices`) before executing broad web searches.
* **Workspace Scoping:** All operations must respect the `WORKSPACE_ROOT` environment boundary. Do not read or write files outside the project worktree.

## 3. Mandatory Workflow Sequence

1. **Scaffold:** Use MCP tools to build structures compliant-by-design.
2. **Write:** Write playbooks/roles utilizing smart Jinja/autocompletion schemas if supported.
3. **Lint:** Run the MCP linting tools immediately after any structural modification.
4. **Execute:** Run playbooks inside the designated MCP execution context to map errors accurately.


# project

## Project Overview

Infrastructure-as-code for a homelab environment managing four Rocky Linux 10 VMs:
- **ansible01** (192.168.100.10): Harbor v2.11.0 container registry
- **ansible02** (192.168.100.11): Grafana/Prometheus/Alertmanager monitoring stack + nginx reverse proxy
- **ansible03** (192.168.100.12): Elasticsearch/Logstash/Kibana (ELK) logging stack
- **ansible04** (192.168.100.13): Nextcloud with Deck integration (collaborative workspace)

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
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐     │
│ │   ansible01  │ │    ansible02  │ │   ansible04  │     │
│ │              │ │              │ │              │     │
│ │  Harbor v2.11│ │ Monitoring   │ │ Nextcloud+Deck│     │
│ │              │ │              │ │              │     │
│ │  /data/harbor│ │ Grafana 3000 │ │ Web :443     │     │
│ │  storage/    │ │ Prometheus   │ │ Deck:443     │     │
│ └──────┬───────┘ │ Alertmanager │ │              │     │
│        │         │ node-exporter│ │              │     │
│        ▼         │ (mTLS:9100)  │ │              │     │
│  nginx :80/443   └──────────────┘ └──────────────┘     │
│  direct HTTP(80) │                     │                │
│                   │    ansible03  │     │
│                   │              │     │
│                   │   ELK Stack   │     │
│                   │              │     │
│                   │ ES:9200/9300 │     │
│                   │ Logstash     │     │
│                   │ Kibana 5601  │     │
└───────────────────┴──────────────┘
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
| `elasticsearch` | Elasticsearch + exporter via pod manifest + PVC | ansible03 |
| `logstash` | Logstash via pod manifest (beats input, grok filters, ES output) | ansible03 |
| `kibana` | Kibana via pod manifest + nginx reverse proxy | ansible03 |
| `node_exporter` | Binary install, systemd service, mTLS web config, textfile collectors | all hosts (sidecar on ELK) |
| `prometheus_exporters` | Download exporter tarballs from internal package repo | localhost (controller) |
| `certificates` | step-ca signed certificates with auto-renewal (≤ 30 days) | all VMs + localhost |
| `step-ca` | Smallstep private CA (v0.30.2), Podman container, auto-init | ansible04 |
| `ca-portal` | nginx cert distribution portal + internal package repo | ansible04 |
| `packages` | Download exporters + textfile scripts to internal package repo | ansible04 |
| `dns` | Unbound DNS server, local zones for homelab.internal, DNSSEC | ansible04 |
| `common` | Package management, protected package safety, chrony, step-cli | all VMs |
| `firewall` | firewalld rules for services, UFW for libvirt host bridge | ansible02, ansible04 |
| `hardening` | STIG/CIS Benchmark (toggleable modules) | all VMs |
| `nginx` | Nginx reverse proxy configuration | ansible01, ansible02, ansible04 |
| `podman` | Podman setup + registries.conf | ansible03 |
| `libvirt` | VM provisioning via `community.libvirt` collection | localhost (provisioner) |

## Rules

### Code Style
1. **No comments in code** unless explicitly requested
2. **YAML**: 2-space indentation, no tabs
3. **Jinja2**: Use `| default()` filter for optional variables
4. **Vault**: Use individual `!vault |` tagged strings, not full-file encryption
```yaml
# Correct — inline encrypted strings in a readable YAML file:
vault_harbor_admin_password: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  616263...
vault_harbor_sync_password: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  646566...

# Wrong — entire file encrypted with `ansible-vault encrypt`:
$ANSIBLE_VAULT;1.1;AES256
616263...
```
5. **Module names**: Always use FQCN (e.g., `ansible.builtin.copy`, not `copy`)

### Binaries in Git
- **Never commit binaries, tarballs, or downloaded artifacts** to the repository
- Add binary directories to `.gitignore` (e.g., `files/prometheus/exporters/`)
- Roles that download files must use `files/` or `reports/` as local staging areas, never commit their contents
- Container images are synced to Harbor, not stored in git

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

## Networking
- All monitoring + ELK services behind nginx reverse proxy on port 443 (HTTPS)
- Harbor directly exposed on HTTP/HTTPS (port 80/443) and metrics (port 8090)
- Use Podman CNI networks for inter-container communication: `elk` and `monitoring`
- mTLS for node-exporter scraping — single shared mTLS CA generated on
  controller (`files/certificates/mtls-ca.crt`, git-trackable; key in
  `files/certificates/mtls-ca.key`, vault-encrypted with `ansible-vault`),
  copied to all hosts at `/etc/mtls/` via `ensure-mtls-ca.yml`. Key is
  decrypted on controller and written as plaintext to hosts. Server/client
  certs signed by this CA.
- DNS entries in `ansible-net` libvirt network

## Playbook Development
1. **Test changes**: Run `ansible-playbook playbooks/provision-ansibleXX.yml` on appropriate host
2. **Idempotency**: Tasks must be idempotent (use `changed_when`, `when` conditions)
3. **Error handling**: Use `failed_when: false` for optional tasks, `register` for output
4. **Handlers**: Use `notify` for dependent restarts, avoid manual restarts

## Inventory Structure

```
inventory/
  hosts.yml              # Group definitions (ansible01, ansible02, ansible03)
  group_vars/all/main.yml           # Centralized versions, host entries, textfile scripts
  group_vars/all/vault.yml          # Vault-encrypted passwords
  group_vars/<group>/main.yml       # Group-specific defaults
  group_vars/harbor/images.yml      # Image definitions with registry mappings
  host_vars/<hostname>/main.yml     # Connection, VM specs, DNS
  host_vars/<hostname>/provision.yml # Playbook-specific variables (optional)
```

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

## References

- [LIFECYCLE.md](LIFECYCLE.md) — Version management, update procedures
- [docs/harbor.md](docs/harbor.md) — Harbor configuration
- [docs/harbor-containers.md](docs/harbor-containers.md) — Harbor container sync
- [docs/prometheus_exporters.md](docs/prometheus_exporters.md) — Exporter tarball downloads
- [docs/monitoring.md](docs/monitoring.md) — Monitoring stack
- [docs/monitoring-configuration.md](docs/monitoring-configuration.md) — Monitoring configuration manual
- [docs/elasticsearch.md](docs/elasticsearch.md) — ELK stack
- [docs/elk-configuration.md](docs/elk-configuration.md) — ELK configuration manual
- [docs/hardening.md](docs/hardening.md) — Hardening modules
- [docs/vm.md](docs/vm.md) — VM lifecycle
- [docs/cloud-kvm.md](docs/cloud-kvm.md) — Cloud KVM setup
- [docs/container-deployment.md](docs/container-deployment.md) — Container deployment patterns
