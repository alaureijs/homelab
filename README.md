# Ansible Infrastructure

Ansible project for managing infrastructure, including libvirt virtual machines.

## Project Structure

```
ansible/
├── ansible.cfg                          # Ansible configuration
├── inventory/
│   ├── hosts.yml                        # Inventory (all host groups)
│   ├── group_vars/
│   │   ├── all.yml                      # Global variables
│   │   ├── all/vault.yml                # Encrypted secrets (ansible-vault)
│   │   ├── webservers.yml               # Webserver group vars
│   │   ├── dbservers.yml                # Database group vars
│   │   └── libvirt.yml                  # Libvirt group vars
│   └── host_vars/
│       ├── web01/main.yml               # Web01 host variables
│       └── ansible01/
│           ├── main.yml                 # Connection, VM specs, network
│           └── provision.yml            # Harbor, packages, firewall
├── playbooks/
│   ├── site.yml                         # Main playbook (webservers, dbservers)
│   └── provision-ansible01.yml          # Provision ansible01 VM for Harbor
├── roles/
│   ├── common/                          # Base packages, NTP
│   ├── nginx/                           # Web server with templated config
│   └── postgres/                        # PostgreSQL installation
└── scripts/
    └── ufw-libvirt.sh                   # UFW rules for libvirt networks
```

## Requirements

- Ansible >= 2.14
- `community.general` and `ansible.posix` collections
- SSH access to target hosts
- `ansible-vault` for encrypted variables

## Quick Start

```bash
# Syntax check
ansible-playbook playbooks/site.yml --syntax-check

# Dry run
ansible-playbook playbooks/site.yml --check

# Limit to a group
ansible-playbook playbooks/site.yml --limit webservers

# Run all
ansible-playbook playbooks/site.yml
```

## Inventory

| Group        | Host      | IP              | Description         |
|--------------|-----------|-----------------|---------------------|
| webservers   | web01     | 192.168.1.10    | Web server          |
| webservers   | web02     | 192.168.1.11    | Web server          |
| dbservers    | db01      | 192.168.1.20    | Database server     |
| monitoring   | mon01     | 192.168.1.30    | Monitoring server   |
| libvirt      | ansible01 | 192.168.100.10  | Rocky Linux 10 VM   |

## Libvirt VM: ansible01

A Rocky Linux 10 VM managed by libvirt, provisioned for running Harbor.

### VM Specifications

All VM variables are defined in `inventory/host_vars/ansible01/`:

**`main.yml`** — connection and hardware:

| Variable       | Value                                  |
|----------------|----------------------------------------|
| ansible_host   | 192.168.100.10                         |
| vm_vcpus       | 2                                      |
| vm_memory      | 2048                                   |
| vm_disk        | 60                                     |
| vm_network     | ansible-net                            |
| vm_mac         | 52:54:00:aa:00:10                      |

**`provision.yml`** — software and services:

| Variable            | Value                              |
|---------------------|------------------------------------|
| harbor_version      | v2.11.0                            |
| timezone            | Europe/Amsterdam                   |
| firewall_ports      | 80, 443, 22                        |

### Managing the VM

```bash
# VM lifecycle
virsh list --all                        # List VMs
virsh start ansible01                   # Start
virsh shutdown ansible01                # Graceful shutdown
virsh destroy ansible01                 # Force stop
virsh undefine ansible01 --nvram        # Remove (keeps disk)
virsh console ansible01                 # Serial console
virsh domifaddr ansible01               # Show IP addresses

# Network
virsh net-list --all                    # List networks
virsh net-dhcp-leases ansible-net       # DHCP leases
virsh net-dumpxml ansible-net           # Network XML

# Storage
virsh pool-list --all                   # List pools
virsh pool-info sdb                     # Pool status
```

### Provisioning

```bash
# Run the provisioning playbook
ansible-playbook playbooks/provision-ansible01.yml

# Check connectivity
ansible ansible01 -m ping

# SSH in
ssh root@192.168.100.10
```

### Cloud-init

Cloud-init ISO is generated at `/var/lib/libvirt/sdb/ansible01-cloudinit.iso`.
To regenerate after changes:

```bash
cloud-localds /tmp/cloud-init.iso /tmp/user-data
sudo cp /tmp/cloud-init.iso /var/lib/libvirt/sdb/ansible01-cloudinit.iso
```

Note: the VM must be destroyed and recreated for cloud-init to re-apply.

### UFW Rules (Host)

UFW on the host blocks libvirt bridge traffic by default. Run the script
after any UFW reset or reload:

```bash
sudo ./scripts/ufw-libvirt.sh
```

This adds route rules for `virbr-ansible` to allow:
- Guest cross-traffic (DHCP, DNS)
- NAT forwarding to all external interfaces (wlan1, enp109s0f1, etc.)

### Vault

Root password is stored encrypted in `inventory/group_vars/all/vault.yml`.

```bash
# View vault password file
cat .vault_password

# Edit encrypted vars
ansible-vault edit inventory/group_vars/all/vault.yml

# View encrypted vars
ansible-vault view inventory/group_vars/all/vault.yml
```

## Host Firewall (UFW)

The host runs UFW with default deny. Required rules:

```
Anywhere on virbr-ansible         ALLOW IN    Anywhere
Anywhere on virbr-ansible         ALLOW FWD   Anywhere on virbr-ansible
Anywhere                          ALLOW FWD   Anywhere on virbr-ansible
```

Use `scripts/ufw-libvirt.sh` to apply these automatically.

## Environment

- **Host OS**: CachyOS (Arch-based), kernel 7.1.x
- **Libvirt**: 12.5.0
- **Python**: 3.14.6
- **Storage pool**: `sdb` on `/dev/sdb` (XFS, 465 GB Samsung SSD)
- **Network**: `ansible-net` (NAT, bridge `virbr-ansible`)

## License

Internal use.
