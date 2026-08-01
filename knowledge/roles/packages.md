---
type: Ansible Role
title: packages
description: "Download exporters, Harbor installer, and textfile scripts to the internal package repo."
resource: roles/packages/
tags: [packages, repo]
status: stable
generated:
  by: human:alaureijs
  at: 2026-08-01T14:00:00Z
verified:
  - by: human:alaureijs
    at: 2026-08-01T14:00:00Z
  - by: human:alaureijs
    at: 2026-08-01T14:00:00Z
    note: molecule coverage added
---

Download exporters, Harbor installer, and textfile scripts to the internal package repo.

## Molecule Testing

Validated via molecule (podman driver) in isolated containers — `default`,
`minimum`, `full` scenarios, all green (syntax, converge, idempotence,
verify).

- **default** — single exporter (node_exporter v1.12.1) download
- **minimum** — empty exporter/file/script lists (role must tolerate
  undefined `packages_exporter_info` and report)
- **full** — two exporters + textfile script uploads

The role tolerates empty `packages_exporters`; the exporter report tasks are
guarded so minimum converges with no upstream GitHub access needed for
reports.

```bash
export ANSIBLE_ALLOW_BROKEN_CONDITIONALS=1
cd roles/packages && molecule test -s default
```

## Related

* [packages](/services/packages.md)
* [sync-content](/playbooks/sync-content.md)
