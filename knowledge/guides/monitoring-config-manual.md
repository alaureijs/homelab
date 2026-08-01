---
type: Guide
title: Monitoring configuration manual
description: Variable-driven configuration of the monitoring stack without editing role files.
tags: [monitoring, grafana, prometheus, configuration]
status: stable
sources:
  - id: monitoring-config-doc
    resource: ../../docs/monitoring-configuration.md
    title: Monitoring configuration manual
    last_modified: 2026-07-31
generated:
  by: human:alaureijs
  at: 2026-08-01T14:30:00Z
verified:
  - by: human:alaureijs
    at: 2026-08-01T14:30:00Z
---

## Key variables

Set in `inventory/group_vars/monitoring/main.yml`:

| Variable | Default | Description |
|----------|---------|-------------|
| `monitoring_grafana_admin_password` | `admin` | Grafana admin |
| `monitoring_prometheus_retention` | `30d` | retention window |
| `monitoring_prometheus_scrape_interval` | `15s` | scrape interval |
| `monitoring_alertmanager_smtp_smarthost` | `""` | SMTP server |
| `monitoring_hostname` | `monitoring.homelab.internal` | proxy hostname |

Config file locations are overridable (`monitoring_prometheus_config_template`,
`monitoring_prometheus_rules_file`, etc.) to keep custom configs out of the
role.[^monitoring-config-doc]

## Common tasks

- **Add a dashboard**: export JSON → `roles/monitoring/files/dashboards/` →
  add to `monitoring_grafana_dashboards` → re-run `provision-ansible02.yml`.
- **Add scrape target / rule / receiver**: edit config, apply with
  `podman cp` + `podman exec <c> kill -HUP 1` (no restart).

## Resource tuning

Retention and size via `monitoring_prometheus_retention*`; pod memory limits
in the pod manifest template.

## Reload without restart

```bash
podman exec monitoring-prometheus kill -HUP 1
podman exec monitoring-alertmanager kill -HUP 1
```

[^monitoring-config-doc]: Monitoring configuration manual — full variable reference and how-to
