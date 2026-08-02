# Directory Update Log

## 2026-08-02
* **Update**: `libvirt-teardown` now also destroys/undefines the `sdb` storage pool and deletes `/var/lib/libvirt/sdb` — the pool was dir-backed and held orphaned VM artifacts (old ansible01-03 qcow2, `vm-rhel-10-stream.qcow2`, VARS, ISOs, console logs) from a prior generation. Executed: pool gone from system daemon, directory removed; `boot`/`default` pools untouched.
* **Creation**: Added playbook `libvirt-teardown` — destroys/undefines all lab VMs, removes `ansible-net` and `project01` networks, deletes qcow2/VARS/ISO/base cloud image, and clears UFW bridge + route rules (system daemon only; guard `libvirt_teardown_confirm=true`). Registered in `playbooks/index.md`; linked from `roles/libvirt.md`.
* **Update**: Teardown executed — ansible01–04 destroyed/undefined (UEFI NVRAM removed), VM disks/ISOs and cached Rocky cloud image deleted, `ansible-net` + `project01` undefined, UFW rules for `virbr-ansible` (DHCP/DNS v4+v6 + route rules) removed. Lab host returned to bare state (`default` network and libvirtd untouched).

## 2026-08-01
* **Update**: Fixed knowledge/doc inconsistencies — `packages.md` source
  no longer cites deprecated `docs/prometheus_exporters.md` (removed
  exporters-doc source + footnote); `ansible01.md` spec table gained vCPU
  row; `docs/vm.md` ansible01 RAM corrected 2 GB → 4 GB (matches
  `inventory/host_vars/ansible01/main.yml`).
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
