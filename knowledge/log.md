# Directory Update Log

## 2026-08-01
* **Update**: Registered external references as OKF Reference concepts —
  Knowledge Catalog, Ansible Style Guide, Caveman, AutoResearch, Karpathy
  System Prompt Gist, Multica Karpathy Skills. Added to root index and
  regenerated `references/index.md` (bare URL list replaced).
* **Update**: Added molecule coverage for 5 roles — `common`, `podman`,
  `firewall`, `nginx`, `packages` — each with `default`/`minimum`/`full`
  scenarios run in isolated Podman containers (all 15 green). Fixed
  idempotency in `firewall` (handler-based reload), empty-exporter handling
  in `packages`, and verify assertions in `podman` (socket via systemctl).
  Role concepts updated with Molecule Testing sections.
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
