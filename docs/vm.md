# Virtual Machines

Libvirt VMs on CachyOS host, running Rocky Linux 10.2.

## VMs

| Host | IP | vCPU | RAM | Disk | MAC | Purpose |
|------|----|------|-----|------|-----|---------|
| ansible01 | 192.168.100.10 | 2 | 2 GB | 60 GB | 52:54:00:aa:00:10 | Harbor registry |
| ansible02 | 192.168.100.11 | 2 | 4 GB | 80 GB | 52:54:00:aa:00:11 | Monitoring stack |

## Network

- **Name**: `ansible-net` (NAT, bridge `virbr-ansible`)
- **Subnet**: 192.168.100.0/24
- **DNS**: `harbor.local.lan` → 192.168.100.10, `monitoring.local.lan` → 192.168.100.11

## Storage

- **Pool**: `sdb` on `/dev/sdb` (XFS, 465 GB, autostarted)

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

## Cloud-init

ISO generated at `/var/lib/libvirt/sdb/ansible01-cloudinit.iso`.
VM must be destroyed and recreated for cloud-init to re-apply.

```bash
cloud-localds /tmp/cloud-init.iso /tmp/user-data
sudo cp /tmp/cloud-init.iso /var/lib/libvirt/sdb/ansible01-cloudinit.iso
```

## Host Firewall (UFW)

UFW blocks libvirt bridge traffic by default. Run after UFW reset/reload:

```bash
sudo ./scripts/ufw-libvirt.sh
```

Adds route rules for `virbr-ansible`:
- Guest cross-traffic (DHCP, DNS)
- NAT forwarding to all external interfaces

## SSH

Key: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJVQm49wmi1cN68l8/SNN5Hivj7fbeQGKA6dHRahpcDL`

```bash
ssh root@192.168.100.10   # ansible01
ssh root@192.168.100.11   # ansible02
```

## Vault

```bash
ansible-vault edit inventory/group_vars/all/vault.yml
ansible-vault view inventory/group_vars/all/vault.yml
ansible-vault encrypt_string 'my-secret' --name 'vault_new_password'
```
