---
type: Virtual Machine
title: ansible04
description: PKI, DNS, and portal host (192.168.100.13), Rocky Linux 10.2 under libvirt.
resource: ssh://root@192.168.100.13
tags: [vm, pki, dns, libvirt]
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
| Hostname | `ansible04` |
| IP | 192.168.100.13 |
| MAC | 52:54:00:aa:00:13 |
| vCPU | 2 |
| Memory | 4 GB |
| Disk | 60 GB |
| OS | Rocky Linux 10.2 |
| Inventory groups | pki, portal, packages, libvirt, otel |

## Purpose

Central infrastructure host running:
- [/services/step-ca.md](/services/step-ca.md) — private certificate authority
- [/services/dns.md](/services/dns.md) — Unbound recursive resolver, DHCP
  nameserver for all VMs
- [/services/nginx.md](/services/nginx.md) — portal/packages/documents vhosts
- [/services/packages.md](/services/packages.md) — internal package repository

[^vm-doc]: VM documentation — specs table, lifecycle, network, storage
