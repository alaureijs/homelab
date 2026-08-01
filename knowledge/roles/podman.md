---
type: Ansible Role
title: podman
description: "Install Podman, Buildah, Skopeo, podman-compose and configure registries.conf."
resource: roles/podman/
tags: [podman, containers]
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

Install Podman, Buildah, Skopeo, podman-compose and configure registries.conf.

## Molecule Testing

Validated via molecule (podman driver) in isolated containers — `default`,
`minimum`, `full` scenarios, all green (syntax, converge, idempotence,
verify).

- **default** — role defaults: podman + buildah + skopeo + python3-packaging,
  podman-compose pip install, podman.socket enabled, docker.io/quay.io/ghcr.io
  registries
- **minimum** — podman only, no buildah/skopeo/podman-compose, socket
  disabled, docker.io only
- **full** — buildah/skopeo explicitly installed, socket enabled

`ansible.builtin.service_facts` does not report `.socket` units, so socket
state is checked with `systemctl is-active`/`is-enabled` in verify.

```bash
export ANSIBLE_ALLOW_BROKEN_CONDITIONALS=1
cd roles/podman && molecule test -s default
```

## Related

* [harbor](/services/harbor.md)
