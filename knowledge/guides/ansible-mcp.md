---
type: Guide
title: Ansible MCP setup
description: Installing and configuring the Ansible Development Tools MCP server for opencode.
tags: [ansible, mcp, opencode, tooling]
status: stable
sources:
  - id: ansible-mcp-doc
    resource: ../../docs/ansible-mcp.md
    title: Ansible Development Tools MCP Server
    last_modified: 2026-08-01
generated:
  by: human:alaureijs
  at: 2026-08-01T15:00:00Z
verified:
  - by: human:alaureijs
    at: 2026-08-01T15:00:00Z
---

## Register in opencode

MCP server configured in `opencode.json` as `ansible-mcp`[^ansible-mcp-doc]:

```json
"mcp": {
  "ansible-mcp": {
    "type": "local",
    "command": ["npx", "-y", "@ansible/ansible-mcp-server", "--stdio"],
    "enabled": true,
    "environment": { "WORKSPACE_ROOT": "." }
  }
}
```

Restart opencode after editing — MCP loads at startup only.

## Verify

Run `ade_environment_info`; expect Ansible core >= 2.17, ansible-lint,
and installed collections (ansible.posix, community.crypto,
containers.podman, grafana.grafana).

## Install ADT

ADT (ansible-lint, ansible-navigator, ansible-builder, ansible-creator,
molecule) installs via pipx when missing:

```bash
adt_check_env        # via MCP tool
pipx install ansible-dev-tools
```

ADE = environment manager layer (venvs, collections, pip requirements).

## Additional MCP servers

Registered in `opencode.json` alongside `ansible-mcp`[^ansible-mcp-doc]:

| Server | Command | Status |
|--------|---------|--------|
| grafana | `uvx mcp-grafana` | needs service account token |
| podman | `npx -y podman-mcp-server@latest` | works |
| kubernetes | `npx -y kubernetes-mcp-server@latest` | inert — no cluster |
| elasticsearch | `uvx elasticsearch-mcp-server` | works (security disabled) |
| obsidian | `uvx mcp-obsidian` | needs Obsidian REST API plugin |
| github | `podman run ghcr.io/github/github-mcp-server` | needs PAT |
| libvirt | `uv --directory ~/.local/share/mcp-servers/libvirt-mcp run server.py` | works |

- Grafana/ES connect to `monitoring.homelab.internal` / `192.168.100.12:9200`.
- `CHANGEME-*` placeholders must be filled (Grafana SA token, GitHub PAT,
  Obsidian API key) — see docs/ansible-mcp.md.
- libvirt clone pinned to `libvirt-python==12.5.0` to match system libvirt
  (11.3.0 sdist fails to build).

## Usage rules

- Run playbooks via `ansible_navigator` (with `--check` first), not raw
  `ansible-playbook` in the shell.
- Lint after structural changes with `ansible_lint`.
- All playbook testing inside Podman/Docker sandbox (molecule test).
- `WORKSPACE_ROOT: "."` bounds all server ops to repo root.

## Troubleshooting

- Tools missing → check `opencode.json`, restart opencode, run
  `list_available_tools` (names drift across versions).
- `npx` fails → Node on PATH; `-y` auto-installs; purge npx cache if stale.
- Missing Python/Ansible → verify PATH/version; run `adt_check_env`.

[^ansible-mcp-doc]: docs/ansible-mcp.md — full setup, tool overview, and troubleshooting
