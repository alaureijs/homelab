---
type: Ansible Role
title: common
description: "Install base packages, chrony, journald retention, step-cli; shared OS baseline."
resource: roles/common/
tags: [common, base]
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

Install base packages, chrony, journald retention, step-cli; shared OS baseline.

## Molecule Testing

Validated via molecule (podman driver) in isolated containers — `default`,
`minimum`, `full` scenarios, all green (syntax, converge, idempotence,
verify).

- **default** — role defaults with the full feature surface
- **minimum** — minimal deployment, essential services only
- **full** — full environment validation

Chrony is disabled in all scenarios (`common_enable_chrony: false`):
`chronyd` cannot run in a rootless user-namespaced container
(`adjtimex` EPERM). Verify asserts the `/usr/sbin/chronyd` binary is present
and the service is not running.

```bash
export ANSIBLE_ALLOW_BROKEN_CONDITIONALS=1
cd roles/common && molecule test -s default
```

## Related

* [step-ca](/services/step-ca.md)
