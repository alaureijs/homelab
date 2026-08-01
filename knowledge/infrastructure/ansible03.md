---
type: Virtual Machine
title: ansible03
description: ELK logging stack host (192.168.100.12), Rocky Linux 10.2 under libvirt.
resource: ssh://root@192.168.100.12
tags: [vm, elk, libvirt]
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
| Hostname | `ansible03` |
| IP | 192.168.100.12 |
| MAC | 52:54:00:aa:00:12 |
| vCPU | 2 |
| Memory | 8 GB |
| Disk | 120 GB |
| OS | Rocky Linux 10.2 |
| Inventory groups | elk, libvirt, otel |

## Purpose

Runs the [/services/elasticsearch.md](/services/elasticsearch.md),
[/services/logstash.md](/services/logstash.md), and
[/services/kibana.md](/services/kibana.md) pods in host network mode.
Also serves the nginx mTLS-gated `/elasticsearch/` endpoint that the
[/services/otel.md](/services/otel.md) collectors push logs to.

[^vm-doc]: VM documentation — specs table, lifecycle, network, storage
