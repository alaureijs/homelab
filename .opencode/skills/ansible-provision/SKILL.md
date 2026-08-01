---
name: ansible-provision
description: Deploy or update a playbook/role to the homelab VMs following the mandatory MCP workflow (verify toolchain, lint, check-mode, run, idempotency, knowledge sync)
metadata:
  workflow: provision
---

# ansible-provision

## What I do
- Run an Ansible playbook against the homelab VMs using the ansible-mcp toolchain, never raw ansible-playbook.
- Verify toolchain first, lint, dry-run with `--check`, then run for real.
- Confirm idempotency and sync the OKF knowledge wiki afterward.

## When to use me
Use when deploying, updating, or debugging a playbook/role against
ansible01-04 (Harbor, monitoring, ELK, PKI, otel, common). Also for
re-running a provisioning playbook after a version bump or cert renewal.

## Playbook map
| Target | Playbook |
|--------|----------|
| ansible01 (Harbor) | `playbooks/provision-ansible01.yml` |
| ansible02 (monitoring) | `playbooks/provision-ansible02.yml` |
| ansible03 (ELK) | `playbooks/provision-ansible03.yml` |
| ansible04 (PKI/DNS/nginx) | `playbooks/provision-ansible04.yml` |
| all VMs (common/certs/otel) | `playbooks/provision-common.yml`, `playbooks/provision-otel.yml` |
| libvirt VMs (localhost) | `playbooks/libvirt.yml` |
| image sync | `playbooks/sync-content.yml` |

## Steps
1. Verify toolchain: `ade_environment_info` / `adt_check_env`.
2. Edit playbook/role files.
3. Lint: `ansible_lint` on the changed playbook/role.
4. Dry-run: `ansible_navigator` with `--check`.
5. If lint or syntax fails: mark FAILED, fix, re-test.
6. Run playbook via `ansible_navigator` (stdout mode).
7. Verify services on target host (podman ps, systemctl, curl health).
8. Run `knowledge-update` skill if infra changed.
