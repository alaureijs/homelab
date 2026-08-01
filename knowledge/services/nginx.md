---
type: Service
title: nginx reverse proxy
description: Data-driven nginx vhosts on ansible04 serving portal, packages, and documents.
resource: https://pki.homelab.internal/
tags: [nginx, web, portal]
status: stable
sources:
  - id: pki-doc
    resource: ../../docs/pki-step-ca.md
    title: step-ca documentation (CA portal section)
    last_modified: 2026-07-31
generated:
  by: human:alaureijs
  at: 2026-08-01T13:30:00Z
verified:
  - by: human:alaureijs
    at: 2026-08-01T13:30:00Z
---

## Runtime

- nginx on [/infrastructure/ansible04.md](/infrastructure/ansible04.md);
  vhosts generated from `nginx_vhosts` +
  `nginx_directories` in `inventory/group_vars/portal/main.yml`, all rendered
  from a single `roles/nginx/templates/vhost.conf.j2`.[^pki-doc]

## Vhosts

| Hostname | Purpose |
|----------|---------|
| `pki.homelab.internal` | CA portal: landing page, root/intermediate cert download, ACME proxy |
| `packages.homelab.internal` | Internal package repo (autoindex) |
| `documents.homelab.internal` | Documents portal (reports, sync reports) |

Feature flags in `nginx_vhosts` toggle ACME challenge handling, CA alias,
autoindex, and landing page index.html. TLS certs per vhost from the
`certificates` role (step-ca issued).

## Endpoints

- `/ca/root.crt`, `/ca/intermediate.crt` — CA certificate downloads
- `/.well-known/acme-challenge/` — ACME HTTP-01
- `/acme/` — proxied to step-ca ACME directory

## Also deployed

The monitoring and ELK stacks run their own nginx proxies on ansible02/
ansible03 respectively for `/grafana/`, `/prometheus/`,
`/kibana/`, `/elasticsearch/` (mTLS-gated).

[^pki-doc]: step-ca documentation — CA portal vhosts, endpoints, ACME
