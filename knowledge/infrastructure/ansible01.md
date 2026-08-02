---
type: Virtual Machine
title: ansible01
description: Harbor registry host (192.168.100.10), Rocky Linux 10.2 under libvirt.
resource: ssh://root@192.168.100.10
tags: [vm, harbor, libvirt]
status: stable
sources:
  - id: vm-doc
    resource: ../../docs/vm.md
    title: Virtual machines documentation
    last_modified: 2026-07-31
  - id: cloud-kvm-doc
    resource: ../../docs/cloud-kvm.md
    title: Cloud images in KVM guide
    last_modified: 2026-07-31
generated:
  by: human:alaureijs
  at: 2026-08-01T12:30:00Z
verified:
  - by: human:alaureijs
    at: 2026-08-01T12:30:00Z
---

## Spec

| Attribute | Value |
|-----------|-------|
| Hostname | `ansible01` |
| IP | 192.168.100.10 |
| MAC | 52:54:00:aa:00:10 |
| vCPU | 2 |
| Memory | 4 GB |
| Disk | 60 GB (qcow2, backing-image) |
| OS | Rocky Linux 10.2 |
| Firmware | UEFI/OVMF, VirtIO |
| Inventory groups | harbor, libvirt, otel |

## Purpose

Runs [/services/harbor.md](/services/harbor.md) container registry.
`hardening_ip_forwarding: true` (Podman networking requires it).
OTel filelog ships `/var/log/harbor/*.log` to ELK.

## Management

```bash
ssh root@192.168.100.10
virsh domifaddr ansible01        # from the CachyOS host
```

Provisioned by the [libvirt role](/roles/libvirt.md) with cloud-init;[^vm-doc]
full lifecycle in [cloud-init guide](/infrastructure/cloud-init.md).[^cloud-kvm-doc]

[^vm-doc]: VM documentation — specs table, lifecycle, network, storage, cloud-init
[^cloud-kvm-doc]: Cloud images in KVM — backing images, UEFI, NoCloud ISO
