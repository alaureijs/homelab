---
type: Ansible Role
title: firewall
description: "Firewalld rules for services; UFW bridge rules for the libvirt host."
resource: roles/firewall/
tags: [firewall, network]
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

Firewalld rules for services; UFW bridge rules for the libvirt host.

## Molecule Testing

Validated via molecule (podman driver) in isolated containers — `default`,
`minimum`, `full` scenarios, all green (syntax, converge, idempotence,
verify).

- **default** — firewalld backend with default ports 80/443 + ssh
- **minimum** — minimal ruleset
- **full** — full ruleset validation

firewalld changes are applied via handlers (`notify: Reload firewalld` +
`flush_handlers`) so re-runs are idempotent.

```bash
export ANSIBLE_ALLOW_BROKEN_CONDITIONALS=1
cd roles/firewall && molecule test -s default
```

## Related

* [network](/infrastructure/network.md)
