---
type: Guide
title: Container image sync
description: How image versions are pinned, synced to Harbor, and updated.
tags: [harbor, sync, images, versions]
status: stable
sources:
  - id: harbor-doc
    resource: ../../docs/harbor.md
    title: Harbor documentation (updating images section)
    last_modified: 2026-07-31
  - id: harbor-containers-doc
    resource: ../../docs/harbor-containers.md
    title: harbor_containers role documentation
    last_modified: 2026-07-31
generated:
  by: human:alaureijs
  at: 2026-08-01T14:30:00Z
verified:
  - by: human:alaureijs
    at: 2026-08-01T14:30:00Z
---

## Single source of truth

Versions live in `inventory/group_vars/all/main.yml`
(`harbor_version`, `grafana_version`, `prometheus_version`, ...); the image
list with tags and registries in `inventory/group_vars/harbor/images.yml`
(`harbor_sync_images` + `harbor_config_proxy_projects`).

## Sync pipeline

`playbooks/sync-content.yml` → [harbor_containers role](/roles/harbor_containers.md):

1. Auth to Harbor (sync user, `developer` role)
2. Pull each image (proxy-cache or direct upstream)
3. Retag into the destination project (first path component)
4. Push to Harbor
5. `skopeo list-tags` upstream check for newer versions; auto-syncs the
   latest matching tag
6. Report to `reports/sync-report-<date>.yml` + documents site[^harbor-containers-doc]

## Updating a version

```bash
# bump the version in group_vars/all/main.yml (or images.yml)
ansible-playbook playbooks/sync-content.yml          # sync
ansible-playbook playbooks/sync-content.yml --check  # report-only
# then re-run the affected host's provisioning playbook
```

## Naming convention

`name: <project>/<image>` → Harbor path `harbor.homelab.internal/<project>/<image>:<tag>`.
Registry → proxy project mapping via `harbor_config_proxy_projects`; unused
in direct mode (`harbor_containers_use_proxy_cache: false`).

[^harbor-doc]: Harbor documentation — updating container images
[^harbor-containers-doc]: harbor_containers role — pipeline, naming, reports, troubleshooting
