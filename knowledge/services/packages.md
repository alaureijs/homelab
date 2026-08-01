---
type: Service
title: Packages repository
description: Internal nginx-hosted package repo on ansible04 for exporters, the Harbor installer, and textfile scripts.
resource: https://packages.homelab.internal/
tags: [packages, repo, downloads]
status: stable
sources:
  - id: exporters-doc
    resource: ../../docs/prometheus_exporters.md
    title: Exporter downloads documentation
    last_modified: 2026-07-31
generated:
  by: human:alaureijs
  at: 2026-08-01T13:30:00Z
verified:
  - by: human:alaureijs
    at: 2026-08-01T13:30:00Z
---

## Purpose

Centralizes binary downloads so VMs install from an internal origin instead
of upstream GitHub releases. Served by [/services/nginx.md](/services/nginx.md)
as the `packages.homelab.internal` autoindex vhost.[^exporters-doc]

## Contents

- Prometheus exporter tarballs (node_exporter, pushgateway,
  elasticsearch-exporter, mysqld_exporter, postgres_exporter,
  nginx-prometheus-exporter, logstash-exporter)
- Harbor offline installer tarball
- Node-exporter textfile scripts
- OTel collector binary

Versions pinned via `packages_exporters` and `*_version` vars in
`inventory/group_vars/all/main.yml`; refreshed by
[/playbooks/sync-content.md](/playbooks/sync-content.md) (first play, runs
the [packages role](/roles/packages.md) on ansible04).

[^exporters-doc]: Exporter downloads — merged into the packages role
