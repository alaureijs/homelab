---
type: Guide
title: Cloud-init provisioning
description: NoCloud first-boot configuration applied to every libvirt VM.
resource: roles/libvirt/templates/user-data.j2
tags: [libvirt, cloud-init, provisioning]
status: stable
sources:
  - id: cloud-kvm-doc
    resource: ../../docs/cloud-kvm.md
    title: Cloud images in KVM guide
    last_modified: 2026-07-31
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

## How it works

The [libvirt role](/roles/libvirt.md) renders `user-data` + `meta-data`
from templates and builds a NoCloud ISO with `cloud-localds`, attached as a
read-only CD-ROM. Cloud-init applies it on first boot only (semaphore file in
`/var/lib/cloud/`). ISOs are regenerated on every playbook run; VMs must be
destroyed/recreated for changes to re-apply.[^cloud-kvm-doc]

## What gets applied

- Hostname and `/etc/hosts`
- Root SSH key (dual-delivered: `users` module + `write_files`) and
  `PermitRootLogin yes`
- Base packages: curl, wget, git, vim, lvm2, device-mapper
- DNS search domains via `nmcli` (`homelab.internal`)
- `package_update` / `package_upgrade` on first boot (2–5 min; SSH refused
  until it completes)

## Re-running cloud-init

```bash
ssh root@<vm> cloud-init status
# from inside the guest, to force a re-run:
rm -rf /var/lib/cloud/ && reboot
```

[^cloud-kvm-doc]: Cloud images in KVM — NoCloud data source, user-data/meta-data
[^vm-doc]: VM documentation — cloud-init section
