---
type: Playbook
title: libvirt-teardown
description: "Destroy/undefine all libvirt lab VMs, remove ansible-net and project01 networks, delete VM disks/VARS/ISOs and cached cloud image, and clear UFW bridge rules; idempotent."
resource: playbooks/libvirt-teardown.yml
tags: [libvirt, vm, teardown]
status: stable
generated:
  by: human:alaureijs
  at: 2026-08-02T14:00:00Z
verified:
  - by: human:alaureijs
    at: 2026-08-02T14:00:00Z
---

Destructive teardown of the libvirt lab back to a bare host. Inverse of [libvirt](/playbooks/libvirt.md). Refuses to run unless `-e libvirt_teardown_confirm=true`.

## Actions

* `community.libvirt.virt` destroy + undefine each VM in the `libvirt` inventory group (undefine flags `managed_save`, `snapshots_metadata`, `nvram`, `checkpoints_metadata` — the `nvram` flag also removes the per-VM `_VARS.fd` file).
* Delete `{{ libvirt_storage_path }}/<vm>.qcow2`, `<vm>_VARS.fd`, `<vm>-cloudinit.iso`, and the cached `Rocky-10-GenericCloud-Base-latest.x86_64.qcow2`.
* `community.libvirt.virt_net` destroy + undefine for each network in `libvirt_networks` (`ansible-net`, `project01`).
* Delete UFW DHCP (67/udp) and DNS (53/udp+tcp) rules on the bridge, plus the `route allow` rules (guest cross-traffic, NAT via `wlan0`) using `ufw route delete` command tasks.

## Notes

* Operates on the system libvirt daemon (`qemu:///system`); the controller's default `virsh` URI is `qemu:///session`, so verify teardown with `sudo virsh -c qemu:///system`.
* `community.libvirt.virt_net` command-based `undefine` never reports `changed`, and `destroy` on an inactive network raises (suppressed with `failed_when: false`) — absence is confirmed via the system daemon, not task state.
* The `default` network and `libvirtd`/packages are left untouched; re-run `playbooks/libvirt.yml` to recreate the lab (re-downloads the cloud image).

## Related

* [libvirt](/playbooks/libvirt.md)
* [libvirt](/roles/libvirt.md)
* [network](/infrastructure/network.md)
