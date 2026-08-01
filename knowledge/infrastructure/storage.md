---
type: Asset
title: sdb storage pool
description: Directory-backed libvirt storage pool holding VM disks and cloud-init ISOs.
resource: file:///var/lib/libvirt/sdb
tags: [storage, libvirt, xfs]
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
  at: 2026-08-01T13:00:00Z
verified:
  - by: human:alaureijs
    at: 2026-08-01T13:00:00Z
---

## Layout

| Path | Purpose |
|------|---------|
| `/var/lib/libvirt/sdb/` | pool root (dir-backed, XFS, fstab entry, autostarted) |
| `/var/lib/libvirt/images/` | cached Rocky Linux GenericCloud base image |
| `/var/lib/libvirt/sdb/<vm>.qcow2` | per-VM delta disks (backing-image CoW) |
| `/var/lib/libvirt/sdb/<vm>_VARS.fd` | per-VM UEFI NVRAM |
| `/var/lib/libvirt/sdb/<vm>-cloudinit.iso` | NoCloud cloud-init ISOs |

## VM disks

- qcow2 CoW disks backed by the cached cloud image; resized to the VM's
  target (`vm_disk`).[^cloud-kvm-doc]
- Each VM has its own `OVMF_VARS.fd` copy — never shared, or UEFI state
  corrupts across VMs.
- The libvirt role skips resize when the disk is already at target size and
  opens running images with `qemu-img info -U`.

## Growing a disk

Two steps: expand the qcow2 on the host (`qemu-img resize`, or
`virsh blockresize` for live), then grow the filesystem inside the guest
(`growpart` + `xfs_growfs` on the cloud-image partition layout).[^vm-doc]

[^vm-doc]: VM documentation — storage section, disk resize steps
[^cloud-kvm-doc]: Cloud images in KVM — backing images, resize workflow
