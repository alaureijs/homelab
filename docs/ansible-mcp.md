# Ansible Development Tools MCP Server

Ansible MCP server for the Ansible Development Tools (ADE/ADT) ecosystem.
Registers with opencode as `ansible-mcp` and exposes Ansible-specific tools
(lint, navigator, environment setup, scaffolding) to AI agents.

## Prerequisites

- Node.js (for `npx` to run the server)
- Python 3.14+ with Ansible core >= 2.17 installed
- Collections: `ansible.posix`, `community.crypto`, `containers.podman`,
  `grafana.grafana` (verify with `ade_environment_info`)
- pipx (for ADT installation)

## Setup

### 1. Configure `opencode.json`

```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [ "docs/ansible-mcp.md" ],
  "mcp": {
    "ansible-mcp": {
      "type": "local",
      "command": ["npx", "-y", "@ansible/ansible-mcp-server", "--stdio"],
      "enabled": true,
      "environment": {
        "WORKSPACE_ROOT": "."
      }
    }
  }
}
```

`WORKSPACE_ROOT: "."` scopes all server operations to the repo root
(`/home/alaureijs/git/homelab`).

### 2. Restart opencode

MCP servers are only loaded at startup. After editing `opencode.json`,
restart opencode before the tools become available.

### 3. Verify connection

Ask the agent to run `ade_environment_info` or check the connected MCP
servers. Expected output:

- Ansible: `ansible [core 2.21.2]`
- Ansible Lint: `ansible-lint 26.6.0`
- Installed collections list

### 4. Install ADT (optional)

ADT (Ansible Development Tools) is not installed by default — it's a
pipx-managed tool suite (ansible-lint, ansible-navigator, ansible-builder,
ansible-creator, molecule):

```bash
adt_check_env        # via MCP tool
# or
pipx install ansible-dev-tools
```

ADE (Ansible Development Environment) is the environment manager layer:
check/set up Python venvs, collections, and pip requirements.

## Tool Overview

| Tool | Purpose |
|------|---------|
| `ade_environment_info` | Check Python, Ansible, ADE/ADT status, collections |
| `ade_setup_environment` | Create venv + install collections/pip requirements |
| `adt_check_env` | Install ansible-dev-tools via pip/pipx |
| `ansible_lint` | Lint playbooks/roles (prefer `ansible-lint <file>` in shell) |
| `ansible_navigator` | Run playbooks (container-aware, `--check` for dry-run) |
| `create_ansible_projects` | Scaffold collections/playbook projects |
| `define_and_build_execution_env` | Build/validate execution environment definitions |
| `ansible_content_best_practices` | Best practices for content authoring |
| `zen_of_ansible` | Ansible design philosophy |

## Additional MCP Servers

Configured alongside `ansible-mcp` in `opencode.json`. All are verified to
start; some need secrets or runtime services before their tools work.

| Server | Command | Env / Secrets | Status |
|--------|---------|---------------|--------|
| `grafana` | `uvx mcp-grafana` | `GRAFANA_URL` (set), `GRAFANA_SERVICE_ACCOUNT_TOKEN` | needs SA token |
| `podman` | `npx -y podman-mcp-server@latest` | none | works |
| `kubernetes` | `npx -y kubernetes-mcp-server@latest` | `KUBECONFIG` (set to `~/.kube/config`) | works — k8s cluster with ArgoCD (`k8s.homelab.internal:6443`) |
| `elasticsearch` | `uvx elasticsearch-mcp-server` | `ELASTICSEARCH_HOSTS` (set, no auth — security disabled) | works |
| `obsidian` | `uvx mcp-obsidian` | `OBSIDIAN_API_KEY` | needs Obsidian + Local REST API plugin running |
| `github` | `podman run ... ghcr.io/github/github-mcp-server` | `GITHUB_PERSONAL_ACCESS_TOKEN` | needs PAT |
| `libvirt` | `uv --directory ~/.local/share/mcp-servers/libvirt-mcp run server.py` | none | works (local clone, pinned `libvirt-python==12.5.0`) |

### Required secrets

Replace the `CHANGEME-*` values in `opencode.json`. Reference vault
variables in `inventory/group_vars/all/vault.yml` where applicable.

| Server | Value | Source |
|--------|-------|--------|
| Grafana SA token | create service account (Editor role) in Grafana UI, copy token | `monitoring.homelab.internal/grafana/` |
| GitHub PAT | classic PAT, `repo` + `read:org` scopes | GitHub settings |
| Obsidian API key | Local REST API plugin settings (default port 27124) | Obsidian vault |

### Kubernetes caveat

The homelab now runs a Kubernetes cluster with ArgoCD (gitops manifests in
`cluster/`, API at `k8s.homelab.internal:6443`). The k8s MCP server uses
`KUBECONFIG=/home/alaureijs/.kube/config`. Note: `podman kube play` is still
used for the VM-hosted services (Harbor, monitoring, ELK, step-ca); the
cluster is separate.

### Grafana subpath

`mcp-grafana` targets the nginx subpath `/grafana/` on
`monitoring.homelab.internal`. Grafana handles the subpath internally.

## Usage Rules

- Use `ansible_navigator` (with `--check` first) to run playbooks, not raw
  `ansible-playbook` via the shell.
- Use `ansible_lint` after any structural modification.
- Do NOT execute host-modifying commands outside the Podman/Docker sandbox
  (molecule test).
- Run `ade_environment_info` / `adt_check_env` before workflows that depend
  on the Ansible toolchain.

## Troubleshooting

### Tools not available in opencode

- Verify `opencode.json` MCP block is correct and `enabled: true`.
- Restart opencode (MCP loads at startup only).
- Run `list_available_tools` to enumerate the live tool set; tool names can
  drift across server versions.

### `npx` fails to start the server

- Check Node.js is installed and on PATH: `node --version`.
- The `-y` flag auto-installs the package on first run (needs network).
- Clear the npx cache if a stale version persists:
  `npx -y @ansible/ansible-mcp-server@latest --version`.

### Server reports missing Python/Ansible

- Verify Ansible core is on PATH and Python version meets requirements
  (>= 3.14.6 in this project).
- Run `adt_check_env` to install the dev tooling via pipx.
