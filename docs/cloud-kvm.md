# Setting Up Virtual Machines with Cloud Images in KVM

A practical guide to building automated VM provisioning with QEMU/KVM,
cloud-init, and Ansible. Covers the concepts behind cloud images and
how this project implements a fully reproducible VM infrastructure.

## Why Cloud Images

Traditional VM setup requires downloading an ISO, booting an installer,
clicking through dialogs, and hoping you remember every setting. Cloud
images eliminate this entirely.

A **cloud image** is a pre-installed, minimally configured OS disk image
designed for automated provisioning. Distribution vendors publish them
for every release — Rocky Linux, Ubuntu, Debian, Fedora all ship
`GenericCloud` images ready to boot.

Key properties:

- **No installer** — the image already has the OS installed
- **Cloud-init ready** — includes cloud-init, which applies configuration
  on first boot (users, SSH keys, packages, networking)
- **Small footprint** — minimal install, no desktop, no docs
- **qcow2 format** — supports thin provisioning via backing images

The workflow is: download the image once, create a copy for each VM,
inject configuration via cloud-init, boot. Done.

## The Building Blocks

### Cloud-init

[Cloud-init](https://cloud-init.io/) is the industry standard for
first-boot instance customization. It runs once, reads configuration
from a **NoCloud** data source (an ISO or attached drive), and applies
it:

- Create users, set SSH keys
- Set hostname, manage `/etc/hosts`
- Install packages
- Run arbitrary commands
- Write files
- Configure networking

Cloud-init uses two files:

| File | Purpose |
|------|---------|
| `user-data` | What to configure (users, packages, commands) |
| `meta-data` | Instance identity (instance-id, hostname) |

These are combined into a FAT ISO using `cloud-localds` and attached
to the VM as a read-only CD-ROM. On first boot, cloud-init detects the
NoCloud data source, reads the files, applies the configuration, and
ignores the ISO on subsequent boots.

### qcow2 Backing Images

Instead of copying the full cloud image for every VM (wasting disk),
QEMU uses **copy-on-write (CoW)** with backing images:

```bash
qemu-img create -f qcow2 \
  -b /path/to/Rocky-10-GenericCloud-Base.qcow2 \
  -F qcow2 \
  /var/lib/libvirt/sdb/ansible01.qcow2
```

This creates a small delta image that references the original. Reads
that haven't been modified are served from the backing file. Writes
go to the delta. A 2 GB cloud image + 3 VMs = ~2 GB + per-VM changes,
not 3x the full image.

After creation, resize to the target disk:

```bash
qemu-img resize ansible01.qcow2 60G
```

The guest sees a 60 GB disk; the backing image remains untouched.

### UEFI/OVMF

Modern Linux distributions expect UEFI firmware. QEMU provides this
via the [EDK2/OVMF](https://github.com/tianocore/edk2) project:

| File | Purpose |
|------|---------|
| `OVMF_CODE.4m.fd` | Shared UEFI firmware (read-only) |
| `OVMF_VARS.4m.fd` | Per-VM NVRAM variables (UEFI settings, boot entries) |

Each VM gets its own copy of `OVMF_VARS` — this stores UEFI state
like Secure Boot keys, boot order, and boot entries. Without a
per-VM copy, VMs would share UEFI state and break each other.

In libvirt XML:

```xml
<loader readonly='yes' type='pflash'>/usr/share/edk2/x64/OVMF_CODE.4m.fd</loader>
<nvram>/var/lib/libvirt/sdb/ansible01_VARS.fd</nvram>
```

### libvirt Networking

libvirt provides virtual networking via iptables/nftables NAT bridges:

```
  VM (virtio)          Host                    Internet
┌─────────────┐   ┌──────────────┐        ┌──────────────┐
│  10.0.0.2   │◄─►│ virbr-ansible│◄──NAT──►│    wlan0     │
│  (guest)    │   │  192.168.100.1│        │              │
└─────────────┘   └──────────────┘        └──────────────┘
                         │
                    dnsmasq (DHCP + DNS)
```

libvirt runs a dnsmasq instance per virtual network that provides:

- **DHCP** — automatic IP assignment to guests
- **DNS** — hostname resolution between guests
- **NAT** — internet access via the host's physical interface

The network is defined as XML and managed by libvirt:

```xml
<network>
  <name>ansible-net</name>
  <forward mode="nat">
    <interface dev="wlan0"/>
  </forward>
  <bridge name="virbr-ansible" stp="on" delay="0"/>
  <ip address="192.168.100.1" netmask="255.255.255.0">
    <dhcp>
      <range start="192.168.100.200" end="192.168.100.254"/>
      <host mac="52:54:00:aa:00:10" name="ansible01" ip="192.168.100.10"/>
    </dhcp>
  </ip>
</network>
```

Static DHCP entries ensure VMs always get the same IP. DNS entries
make hostnames resolvable between guests.

## How This Project Implements It

The `libvirt` role automates the entire workflow. One command provisions
all VMs:

```bash
ansible-playbook playbooks/libvirt.yml
```

### Architecture

```
playbooks/libvirt.yml
        │
        ▼
   roles/libvirt/
   ├── defaults/main.yml    # All configurable variables
   ├── tasks/main.yml       # Provisioning steps
   ├── handlers/main.yml    # Service restart handlers
   └── templates/
       ├── storage-pool.xml.j2   # libvirt pool definition
       ├── network.xml.j2        # libvirt network definition
       ├── vm.xml.j2             # VM domain definition
       ├── user-data.j2          # cloud-init user-data
       ├── meta-data.j2          # cloud-init meta-data
       └── network-config.j2     # cloud-init network config
```

### Step-by-Step Provisioning

Here is what the role does, in order:

#### 1. Packages and Service

Installs `libvirt`, `qemu-full`, `edk2-ovmf`, `cloud-utils`,
`virt-install`, and Python bindings. Ensures `libvirtd` is running
and enabled.

#### 2. Storage Pool

Creates a directory-backed storage pool:

```bash
mkdir -p /var/lib/libvirt/sdb
```

Defined as a libvirt pool so `virsh` commands and VM disk paths
resolve correctly. Autostarted so the pool is available after reboot.

#### 3. Virtual Network

Defines and starts the NAT network with DHCP and DNS:

- Bridge: `virbr-ansible`
- Gateway: `192.168.100.1`
- DHCP: static MAC→IP mappings for all VMs
- DNS: hostname entries from `vm_dns_entries` in host_vars

The forward interface (`wlan0`) is parameterized — change
`libvirt_network_forward_interface` to use a different NIC.

#### 4. UFW Firewall Rules

Adds INPUT rules on the bridge for DHCP (udp/67) and DNS (udp+tcp/53).
Adds route rules for guest cross-traffic and NAT forwarding.

This is critical — without INPUT rules for DHCP, the host's firewall
drops DHCP requests from VMs, and they never get an IP.

#### 5. Cloud Image Download

Downloads the Rocky Linux GenericCloud image once and caches it:

```
/var/lib/libvirt/images/Rocky-10-GenericCloud-Base-latest.x86_64.qcow2
```

The `get_url` module only downloads if the file doesn't exist, so
subsequent runs are instant.

#### 6. Per-VM Disk Creation

For each VM in the `libvirt` inventory group:

1. **Copy OVMF VARS** — fresh copy of `OVMF_VARS.4m.fd` for UEFI NVRAM
2. **Create qcow2 disk** — CoW image backed by the cached cloud image
3. **Resize disk** — compare current size against target, resize only
   if different (idempotent, skips locked disks from running VMs)

The `qemu-img info -U` flag opens the image in shared mode, allowing
size checks while the VM is running.

#### 7. Cloud-init ISO Generation

Renders the user-data and meta-data templates, then builds a NoCloud ISO:

```bash
cloud-localds /var/lib/libvirt/sdb/ansible01-cloudinit.iso \
  /tmp/ansible01-user-data \
  /tmp/ansible01-meta-data
```

The ISOs are regenerated on every playbook run — this ensures template
changes (new SSH keys, different packages) are always reflected.

#### 8. VM Definition and Start

Defines the VM domain from the XML template and starts it:

- **CPU**: host-passthrough (best performance, matches host instructions)
- **Machine**: pc-q35-11.0 (modern chipset with PCIe support)
- **Disk**: VirtIO bus (highest throughput for paravirtualized guests)
- **NIC**: VirtIO network adapter on the virtual network
- **Serial**: pty-based console (accessible via `virsh console`)
- **Guest agent**: QEMU guest agent channel (for host-guest communication)
- **VNC**: auto-assigned port for headless display

### User-data Template

The cloud-init configuration applied to every VM:

```yaml
#cloud-config
hostname: {{ vm_hostname }}
manage_etc_hosts: true

users:
  - name: root
    ssh_authorized_keys:
      - {{ libvirt_ssh_key }}
    lock_passwd: false

write_files:
  - path: /root/.ssh/authorized_keys
    content: "{{ libvirt_ssh_key }}\n"
    permissions: "0600"
    owner: root:root

package_update: true
package_upgrade: true

packages:
  - curl
  - wget
  - git
  - vim
  - lvm2
  - device-mapper-persistent-data

runcmd:
  - nmcli connection modify "System eth0" ipv4.dns-search "{{ vm_hostname }}.local.lan"
  - nmcli connection modify "System eth0" ipv4.dns-search "local.lan"
  - sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
  - systemctl restart sshd
```

Notable details:

- **Dual SSH key delivery** — the `users` module and `write_files` both
  write the key, as a belt-and-suspenders approach to ensure access
- **`PermitRootLogin yes`** — many cloud images default to `prohibit-password`
  or `no`; the `runcmd` step enables root SSH key access
- **`package_update/upgrade`** — runs `dnf update` on first boot (takes
  2–5 minutes; this is why SSH may be initially refused)

### Host Variables

Each VM is defined in `inventory/host_vars/<name>/main.yml`:

```yaml
vm_name: ansible01
vm_mac: "52:54:00:aa:00:10"
vm_ip: "192.168.100.10"
vm_hostname: ansible01
vm_vcpus: 2
vm_memory: 2048
vm_disk: 60
vm_dns_entries:
  - name: harbor.local.lan
    ip: "192.168.100.10"
```

Defaults in `roles/libvirt/defaults/main.yml` cover anything not
specified per-VM.

### Idempotency

The playbook is designed to be run repeatedly:

| Task | Idempotent? | Mechanism |
|------|-------------|-----------|
| Storage pool | Yes | `virt_pool` checks state |
| Network | Yes | `virt_net` checks state |
| Cloud image | Yes | `get_url` skips existing file |
| Disk creation | Yes | `creates:` guard on `qemu-img` |
| Disk resize | Yes | Compares current size vs target |
| Cloud-init ISO | No (always) | Regenerates to reflect template changes |
| VM define | Yes | `virt` re-defines with current XML |
| VM start | Yes | `virt` checks running state |

ISOs are always regenerated because cloud-init only reads them on first
boot — regenerating a stale ISO has no effect on running VMs but ensures
the next fresh boot uses current configuration.

## Manual Workflow

Understanding the manual steps helps with debugging and custom setups.

### Download a Cloud Image

```bash
# Rocky Linux
wget https://dl.rockylinux.org/pub/rocky/10.2/images/x86_64/Rocky-10-GenericCloud-Base-latest.x86_64.qcow2 \
  -O /var/lib/libvirt/images/Rocky-10-GenericCloud-Base-latest.x86_64.qcow2

# Ubuntu
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img \
  -O /var/lib/libvirt/images/ubuntu-24.04-server-cloudimg-amd64.img
```

### Create a VM Disk

```bash
qemu-img create -f qcow2 \
  -b /var/lib/libvirt/images/Rocky-10-GenericCloud-Base-latest.x86_64.qcow2 \
  -F qcow2 \
  /var/lib/libvirt/sdb/myvm.qcow2

qemu-img resize /var/lib/libvirt/sdb/myvm.qcow2 40G
```

### Create Cloud-init Files

```bash
# user-data
cat > /tmp/myvm-user-data << 'EOF'
#cloud-config
hostname: myvm
manage_etc_hosts: true
users:
  - name: root
    ssh_authorized_keys:
      - ssh-ed25519 AAAA...your-key... user@host
package_update: true
packages:
  - curl
  - vim
EOF

# meta-data
cat > /tmp/myvm-meta-data << 'EOF'
instance-id: myvm
local-hostname: myvm
EOF

# Generate ISO
cloud-localds /var/lib/libvirt/sdb/myvm-cloudinit.iso \
  /tmp/myvm-user-data /tmp/myvm-meta-data
```

### Define and Start the VM

```bash
# Copy UEFI VARS
cp /usr/share/edk2/x64/OVMF_VARS.4m.fd /var/lib/libvirt/sdb/myvm_VARS.fd

# Define
virsh define /dev/stdin << 'EOF'
<domain type='kvm'>
  <name>myvm</name>
  <memory unit='MiB'>2048</memory>
  <vcpu>2</vcpu>
  <os>
    <type arch='x86_64' machine='pc-q35-11.0'>hvm</type>
    <loader readonly='yes' type='pflash'>/usr/share/edk2/x64/OVMF_CODE.4m.fd</loader>
    <nvram>/var/lib/libvirt/sdb/myvm_VARS.fd</nvram>
    <boot dev='hd'/>
  </os>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='/var/lib/libvirt/sdb/myvm.qcow2'/>
      <target dev='vda' bus='virtio'/>
    </disk>
    <disk type='file' device='cdrom'>
      <driver name='qemu' type='raw'/>
      <source file='/var/lib/libvirt/sdb/myvm-cloudinit.iso'/>
      <target dev='sda' bus='sata'/>
      <readonly/>
    </disk>
    <interface type='network'>
      <source network='ansible-net'/>
      <model type='virtio'/>
    </interface>
    <graphics type='vnc' port='-1' autoport='yes'/>
  </devices>
</domain>
EOF

# Start
virsh start myvm
```

### Verify

```bash
# Wait for cloud-init (2-5 minutes)
virsh domifaddr myvm                  # Check IP
virsh net-dhcp-leases ansible-net     # DHCP leases

# SSH in
ssh root@<ip-from-above>
```

## Common Pitfalls

### SSH Connection Refused After Boot

Cloud-init runs `package_update`/`package_upgrade` on first boot, which
takes 2-5 minutes depending on mirror speed and update size. The SSH
daemon is not configured until late in the cloud-init process.

Wait, or check progress:

```bash
virsh console myvm                    # Serial console
# or
ping -c 5 <vm-ip>                     # Confirm VM is alive
```

### DHCP Not Assigning IPs

UFW (or firewalld) may block DHCP traffic on the bridge interface.
The host firewall drops incoming UDP port 67 on `virbr-*` by default
because it's forwarded traffic.

Add INPUT rules:

```bash
ufw allow in on virbr-ansible to any port 67 proto udp comment "libvirt DHCP"
ufw allow in on virbr-ansible to any port 53 proto udp comment "libvirt DNS"
ufw allow in on virbr-ansible to any port 53 proto tcp comment "libvirt DNS TCP"
```

### Disk Resize Fails

`qemu-img resize` cannot modify a disk that's in use by a running VM.
Either shut down the VM first, or check that the current size matches
your target before defining the VM.

### Cloud-init Only Runs Once

Cloud-init creates a semaphore file (`/var/lib/cloud/instance/`) after
successfully completing. To re-run it, you must either:

1. Destroy and recreate the VM (what this project does)
2. Manually remove `/var/lib/cloud/` and reboot
3. Use `cloud-init clean` inside the guest

### Shared UEFI VARS

Each VM **must** have its own copy of `OVMF_VARS.fd`. Sharing VARS
files between VMs causes UEFI state corruption — boot entries from
one VM appear in another, and Secure Boot keys conflict.

## References

- [cloud-init documentation](https://cloudinit.readthedocs.io/)
- [QEMU disk images](https://wiki.qemu.org/Documentation/CreateSnapshot)
- [libvirt storage pools](https://libvirt.org/storage.html)
- [libvirt virtual networks](https://libvirt.org/formatnetwork.html)
- [EDK2/OVMF](https://github.com/tianocore/edk2)
- [This project's VM reference](vm.md)
