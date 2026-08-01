---
type: Service
title: Monitoring stack
description: Grafana, Prometheus, and Alertmanager pod on ansible02, served via nginx reverse proxy.
resource: https://monitoring.homelab.internal/
tags: [monitoring, prometheus, grafana, observability]
status: stable
sources:
  - id: monitoring-doc
    resource: ../../docs/monitoring.md
    title: Monitoring stack documentation
    last_modified: 2026-07-31
  - id: monitoring-config-doc
    resource: ../../docs/monitoring-configuration.md
    title: Monitoring configuration manual
    last_modified: 2026-07-31
generated:
  by: human:alaureijs
  at: 2026-08-01T13:30:00Z
verified:
  - by: human:alaureijs
    at: 2026-08-01T13:30:00Z
---

Deployed on [/infrastructure/ansible02.md](/infrastructure/ansible02.md)
via `podman kube play` (one pod, CNI network `monitoring`), all config as
ConfigMaps.[^monitoring-doc]

## Components

| Component | Image (from Harbor) | Port (host) |
|-----------|---------------------|-------------|
| Grafana | `library/grafana/grafana` | 3000 |
| Prometheus | `prometheus/prometheus/prometheus` | 9090 |
| Alertmanager | `prometheus/prometheus/alertmanager` | 9093 |
| Node Exporter | `prometheus/prometheus/node-exporter` | 9100 |

All ports bound to `127.0.0.1` for nginx access only.

## Access

- `https://monitoring.homelab.internal/grafana/`
- `https://monitoring.homelab.internal/prometheus/`
- `https://monitoring.homelab.internal/alertmanager/`

## Scraping

- Node-exporter via FQDN with **mTLS** (shared CA, client certs in
  `/etc/prometheus/mtls/`); containers run as uid 65534, dirs `0755`,
  files `0644`, SELinux `container_file_t`.[^monitoring-doc]
- Harbor metrics (`:8090`, basic auth) and Elasticsearch exporter (`:9114`).
- Prometheus itself exposed via nginx at `/prometheus/metrics`.

## Dashboards and rules

Provisioned via ConfigMaps (`monitoring_grafana_dashboards`). Node Exporter,
Prometheus, Harbor, and Elasticsearch dashboards; alert rules cover CPU,
memory, disk, node-down, Harbor latency/push, and ES cluster health.

## Textfile collectors

Node-exporter textfile scripts run as `nobody` via a systemd timer (5m):
chrony, fstab, reboot-required, authorized-keys, container-health, logstash
(ELK hosts only). SHA256-checksummed, sudoers-gated.

## SELinux

`httpd_can_network_connect` and `httpd_can_network_relay` on (nginx →
pod ports). Cockpit (port 9090 conflict) is auto-disabled.

[^monitoring-doc]: Monitoring documentation — architecture, mTLS, dashboards, textfile collectors, troubleshooting
[^monitoring-config-doc]: Monitoring configuration manual — variable-driven configuration
