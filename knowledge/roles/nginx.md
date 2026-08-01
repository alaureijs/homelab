---
type: Ansible Role
title: nginx
description: "Install nginx and generate data-driven vhosts from nginx_vhosts + vhost.conf.j2."
resource: roles/nginx/
tags: [nginx, web]
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

Install nginx and generate data-driven vhosts from nginx_vhosts + vhost.conf.j2.

## Molecule Testing

Validated via molecule (podman driver) in isolated containers — `default`,
`minimum`, `full` scenarios, all green (syntax, converge, idempotence,
verify).

- **default** — nginx install + default vhosts
- **minimum** — minimal vhost set
- **full** — TLS vhosts with self-signed test certs generated in
  `molecule/full/prepare.yml`

```bash
export ANSIBLE_ALLOW_BROKEN_CONDITIONALS=1
cd roles/nginx && molecule test -s default
```

## Related

* [nginx](/services/nginx.md)
