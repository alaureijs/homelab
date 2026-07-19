# Virtual Machines

Libvirt VMs on CachyOS host, running Rocky Linux 10.2.

## VMs

| Host | IP | vCPU | RAM | Disk | MAC | Purpose |
|------|----|------|-----|------|-----|---------|
| ansible01 | 192.168.100.10 | 2 | 2 GB | 60 GB | 52:54:00:aa:00:10 | Harbor registry |
| ansible02 | 192.168.100.11 | 2 | 4 GB | 80 GB | 52:54:00:aa:00:11 | Monitoring stack |
| ansible03 | 192.168.100.12 | 2 | 8 GB | 120 GB | 52:54:00:aa:00:12 | ELK stack |

## Automation

VMs are provisioned using the `libvirt` role with `community.libvirt` collection:

```bash
ansible-playbook playbooks/libvirt.yml
```

The playbook runs on localhost and creates:
- Storage pool `sdb` (dir-backed, autostarted)
- Network `ansible-net` (NAT via `wlan0`, bridge `virbr-ansible`)
- All VMs from the `libvirt` inventory group with cloud-init

The playbook is idempotent. Cloud-init ISOs are regenerated on every run
(reflecting current template content), but disk resize and VM start are
skipped when already at the desired state.

### Adding a New VM

1. Add to `inventory/hosts.yml` under the `libvirt` group.
2. Create `inventory/host_vars/<name>/main.yml` with required variables:

```yaml
vm_name: myhost
vm_mac: "52:54:00:aa:00:13"
vm_ip: "192.168.100.13"
vm_hostname: myhost
vm_dns_entries:
  - name: myhost.local.lan
    ip: "192.168.100.13"
```

Optional overrides: `vm_vcpus`, `vm_memory`, `vm_disk`.

### What Gets Created

For each VM, the role creates:
- qcow2 disk (backing image from cached cloud image, resized to target)
- Per-VM OVMF VARS file (UEFI NVRAM)
- Cloud-init ISO (user-data + meta-data)
- VM definition with UEFI, VirtIO, serial console, guest agent channel

## Network

- **Name**: `ansible-net` (NAT, bridge `virbr-ansible`)
- **Forward interface**: `wlan0` (configurable via `libvirt_network_forward_interface`)
- **Subnet**: 192.168.100.0/24
- **DHCP range**: 192.168.100.200–254 (static MAC→IP mappings for VMs)
- **DNS**: `harbor.local.lan` → 192.168.100.10, `monitoring.local.lan` → 192.168.100.11, `observability.local.lan` → 192.168.100.12

## Storage

- **Pool**: `sdb` (dir-backed on `/var/lib/libvirt/sdb`, autostarted)
- Cloud image cached at `/var/lib/libvirt/images/`
- VM disks use qcow2 backing image with per-VM NVRAM VARS

## Lifecycle

```bash
virsh list --all                        # List VMs
virsh start ansible01                   # Start
virsh shutdown ansible01                # Graceful shutdown
virsh destroy ansible01                 # Force stop
virsh undefine ansible01 --nvram        # Remove (keeps disk)
virsh console ansible01                 # Serial console
virsh domifaddr ansible01               # Show IP addresses
virsh net-dhcp-leases ansible-net       # DHCP leases
```

### Full Rebuild

To destroy and recreate all VMs from scratch:

```bash
# Destroy all VMs
for vm in ansible01 ansible02 ansible03; do
  sudo virsh destroy $vm 2>/dev/null
  sudo virsh undefine $vm --nvram 2>/dev/null
done

# Remove all files from storage pool
sudo rm -f /var/lib/libvirt/sdb/ansible0*

# Re-run playbook
ansible-playbook playbooks/libvirt.yml
```

Cloud-init runs on first boot only. To re-apply cloud-init, destroy and
recreate the VM (the playbook always regenerates cloud-init ISOs).

## Cloud-init

ISO generated at `/var/lib/libvirt/sdb/<vm>-cloudinit.iso`.

The cloud-init user-data configures:
- Hostname and `/etc/hosts`
- Root SSH key and `PermitRootLogin yes`
- Base packages (curl, wget, git, vim, lvm2)
- DNS search domains via `nmcli`
- `package_update` and `package_upgrade` on first boot

VMs must be destroyed and recreated for cloud-init to re-apply.

## Host Firewall (UFW)

UFW blocks libvirt bridge traffic by default. The `libvirt` role adds
INPUT rules automatically. Run `scripts/ufw-libvirt.sh` after UFW reset/reload:

```bash
sudo ./scripts/ufw-libvirt.sh
```

INPUT rules on `virbr-ansible`:
- DHCP (udp/67) — required for dnsmasq to receive DHCP requests
- DNS (udp+tcp/53)

Route rules on `virbr-ansible`:
- Guest cross-traffic
- NAT forwarding to `wlan0`

## SSH

Key configured in role defaults (`libvirt_ssh_key`):

```bash
ssh root@192.168.100.10   # ansible01
ssh root@192.168.100.11   # ansible02
ssh root@192.168.100.12   # ansible03
```

## Troubleshooting

### VM gets IP but SSH is refused

Cloud-init may still be running `package_update`/`package_upgrade`. Wait
2–5 minutes after boot. Check with:

```bash
ssh root@192.168.100.10 "cloud-init status"
```

### Cloud-init ISO has stale content

The playbook regenerates ISOs on every run (no `creates:` guard). If ISOs
appear stale, verify the playbook ran successfully and the template was
up to date.

### DHCP not assigning static IPs

UFW's `ufw-after-input` chain blocks incoming UDP port 67 (DHCP server)
on the bridge interface. Ensure INPUT rules exist:

```bash
sudo ufw status numbered | grep -E "(67|53).*virbr"
```

If missing, run `scripts/ufw-libvirt.sh` or re-run the playbook.

### Disk resize fails ("write lock")

`qemu-img resize` cannot modify a disk while the VM is running. The
playbook checks current size before resizing. If you need to resize a
running VM's disk, stop it first or use `virsh blockresize`.

## Vault

```bash
ansible-vault edit inventory/group_vars/all/vault.yml
ansible-vault view inventory/group_vars/all/vault.yml
ansible-vault encrypt_string 'my-secret' --name 'vault_new_password'
```
