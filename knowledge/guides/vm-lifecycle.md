---
type: Guide
title: VM lifecycle
description: Day-to-day VM operations — virsh commands, rebuild, adding a VM, troubleshooting.
tags: [libvirt, vm, lifecycle]
status: stable
sources:
  - id: vm-doc
    resource: ../../docs/vm.md
    title: Virtual machines documentation
    last_modified: 2026-07-31
generated:
  by: human:alaureijs
  at: 2026-08-01T14:30:00Z
verified:
  - by: human:alaureijs
    at: 2026-08-01T14:30:00Z
---

## Everyday commands

```bash
virsh list --all                       # list VMs
virsh start / shutdown / destroy <vm>
virsh undefine <vm> --nvram            # remove definition (keeps disk)
virsh console <vm>                     # serial console
virsh domifaddr <vm>                   # IP addresses
virsh net-dhcp-leases ansible-net      # DHCP leases
```

## Adding a VM

1. Add host under the `libvirt` group in `inventory/hosts.yml`
2. Create `inventory/host_vars/<name>/main.yml` (`vm_name`, `vm_mac`,
   `vm_ip`, `vm_hostname`; optional `vm_vcpus`/`vm_memory`/`vm_disk`)
3. Run `ansible-playbook playbooks/libvirt.yml`[^vm-doc]

## Full rebuild

```bash
for vm in ansible01 ansible02 ansible03 ansible04; do
  sudo virsh destroy $vm 2>/dev/null
  sudo virsh undefine $vm --nvram 2>/dev/null
done
sudo rm -f /var/lib/libvirt/sdb/ansible0*
ansible-playbook playbooks/libvirt.yml
```

## Troubleshooting

- IP but SSH refused → cloud-init still running (`cloud-init status`).
- Stale cloud-init → destroy + recreate (ISOs regenerate every run).
- DHCP not static → UFW INPUT rules missing on bridge (`ufw status numbered`).
- Disk resize lock → VM running; use `virsh blockresize` or stop it.

[^vm-doc]: VM documentation — lifecycle, automation, network, storage, troubleshooting
