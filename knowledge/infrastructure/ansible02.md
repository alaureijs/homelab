---
type: Virtual Machine
title: ansible02
description: Monitoring stack host (192.168.100.11), Rocky Linux 10.2 under libvirt.
resource: ssh://root@192.168.100.11
tags: [vm, monitoring, libvirt]
status: stable
sources:
  - id: vm-doc
    resource: ../../docs/vm.md
    title: Virtual machines documentation
    last_modified: 2026-07-31
generated:
  by: human:alaureijs
  at: 2026-08-01T13:00:00Z
verified:
  - by: human:alaureijs
    at: 2026-08-01T13:00:00Z
---

## Spec

| Attribute | Value |
|-----------|-------|
| Hostname | `ansible02` |
| IP | 192.168.100.11 |
| MAC | 52:54:00:aa:00:11 |
| vCPU | 2 |
| Memory | 4 GB |
| Disk | 80 GB |
| OS | Rocky Linux 10.2 |
| Inventory groups | monitoring, libvirt, otel |

## Purpose

Runs [/services/monitoring.md](/services/monitoring.md) stack
(Grafana/Prometheus/Alertmanager) behind nginx. Node-exporter mTLS scraping
originates here for all hosts.

[^vm-doc]: VM documentation — specs table, lifecycle, network, storage
