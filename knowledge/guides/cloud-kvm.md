---
type: Guide
title: Cloud images in KVM
description: Concept guide for building VMs from cloud images — qcow2 backing, UEFI, NoCloud, disk resize.
tags: [kvm, cloud-init, libvirt, qcow2]
status: stable
sources:
  - id: cloud-kvm-doc
    resource: ../../docs/cloud-kvm.md
    title: Cloud images in KVM guide
    last_modified: 2026-07-31
generated:
  by: human:alaureijs
  at: 2026-08-01T14:30:00Z
verified:
  - by: human:alaureijs
    at: 2026-08-01T14:30:00Z
---

## Core ideas

- **Cloud image**: pre-installed OS disk, configured on first boot by
  cloud-init — no installer.
- **qcow2 backing**: per-VM delta disks reference a cached base image
  (CoW); reads served from base, writes to the delta.
- **UEFI/OVMF**: shared read-only `OVMF_CODE` firmware + per-VM `OVMF_VARS`
  NVRAM (never shared — UEFI state corrupts across VMs).
- **NoCloud**: `user-data` + `meta-data` combined with `cloud-localds` into
  an ISO attached as a read-only CD-ROM; runs once on first boot.[^cloud-kvm-doc]

## Disk resize

1. Host: `qemu-img resize <disk> 80G` (or `virsh blockresize` live)
2. Guest: `growpart /dev/vda 4` → `partprobe` → (LVM: `pvresize` +
   `lvextend -l +100%FREE`) → `xfs_growfs /`

## Common pitfalls

- SSH refused right after boot — cloud-init `package_update/upgrade` runs
  2–5 min.
- DHCP fails — host UFW blocks udp/67 on the bridge; re-run
  `scripts/ufw-libvirt.sh`.
- Cloud-init only runs once — remove `/var/lib/cloud/` + reboot to re-run.

## Automation

All of this is automated by the [libvirt role](/roles/libvirt.md)
(`playbooks/libvirt.yml`): pool, network, disks, ISOs, VM definition.

[^cloud-kvm-doc]: Cloud images in KVM — full guide with manual workflow
