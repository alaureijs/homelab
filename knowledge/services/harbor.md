---
type: Service
title: Harbor
description: Harbor v2.11.0 container registry running on ansible01.
resource: https://harbor.homelab.internal/
tags: [registry, containers, harbor]
status: stable
sources:
  - id: harbor-doc
    resource: ../../docs/harbor.md
    title: Harbor documentation
    last_modified: 2026-07-31
  - id: harbor-containers-doc
    resource: ../../docs/harbor-containers.md
    title: harbor_containers role documentation
    last_modified: 2026-07-31
generated:
  by: human:alaureijs
  at: 2026-08-01T12:30:00Z
verified:
  - by: human:alaureijs
    at: 2026-08-01T12:30:00Z
---

Container registry for all internal images, deployed on
[/infrastructure/ansible01.md](/infrastructure/ansible01.md).[^harbor-doc]

## Architecture

- **Install**: offline installer v2.11.0, managed by `podman-compose`
  (not `podman kube play`).
- **Storage**: `/data/harbor` on the 60 GB VirtIO disk.
- **TLS**: certificates from the [/services/step-ca.md](/services/step-ca.md)
  role, auto-renewed within 30 days.
- **Scanner**: Trivy with auto-scan; DB mirrored to project `trivy-db`.

## Access

- Web UI: `https://harbor.homelab.internal/`
- API health: `curl -sk -u admin:$HARBOR_PASSWORD https://harbor.homelab.internal/api/v2.0/health`
- Metrics: `http://harbor.homelab.internal:8090/metrics`

## Users and projects

| User | Role | Purpose |
|------|------|---------|
| admin | system admin | Web UI, system management |
| ansible-config | projectAdmin | API configuration |
| ansible-sync | developer | image push/pull |
| viewer | guest | read-only |
| metrics | guest | Prometheus scraping |

Projects: `library` (synced images), `docker-hub-cache`/`quay-cache`/`ghcr-cache`
(proxy caches). Passwords vault-encrypted in `inventory/group_vars/all/vault.yml`.

## Image sync

Images are synced by the
[harbor_containers role](/roles/harbor_containers.md) via
[/playbooks/sync-content.md](/playbooks/sync-content.md) — pull through a
proxy-cache project, retag into the destination project, push. Proxy-cache
or direct-upstream modes supported.

## Logging

Container logs are routed to `/var/log/harbor/` per-container via rsyslog
(Podman lacks the syslog driver Harbor expects). Logrotate: daily, 14-day
retention.

[^harbor-doc]: Harbor documentation — deployment, users, metrics, logging, troubleshooting
[^harbor-containers-doc]: harbor_containers role — proxy vs. direct sync, reports
