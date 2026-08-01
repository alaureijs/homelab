# Directory Update Log

## 2026-08-01
* **Creation**: Established the OKF v0.2 knowledge bundle: 63 concepts across
  infrastructure, services, playbooks, roles, operations, guides, and
  references. Added tooling (`scripts/okf.py` check + index), committed
  `.obsidian/` vault config, and wired the workflow into AGENTS.md,
  README.md, CHANGELOG.md, and opencode.json.
* **Update**: Added guide "Ansible MCP setup" (`knowledge/guides/ansible-mcp.md`)
  and `docs/ansible-mcp.md`; registered doc in opencode.json instructions.
  ADT (ansible-dev-tools) installed via pipx on controller.
* **Update**: Registered 7 additional MCP servers in `opencode.json` —
  grafana, podman, kubernetes, elasticsearch, obsidian, github, libvirt.
  libvirt via local clone of MatiasVara/libvirt-mcp (pinned
  `libvirt-python==12.5.0`); k8s inert (no cluster). Secrets are
  `CHANGEME-*` placeholders pending Grafana SA token / GitHub PAT /
  Obsidian API key.
