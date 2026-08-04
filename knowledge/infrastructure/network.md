---
type: Network
title: ansible-net
description: NAT virtual network on the CachyOS host bridging VMs to the LAN.
resource: libvirt://ansible-net
tags: [network, libvirt, dns]
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

## Spec

| Attribute | Value |
|-----------|-------|
| Name | `ansible-net` |
| Bridge | `virbr-ansible` |
| Forward | NAT via `wlan0` (configurable: `libvirt_network_forward_interface`) |
| Subnet | 192.168.100.0/24, gateway 192.168.100.1 |
| DHCP range | 192.168.100.200–254 |
| Static leases | VM MAC → IP mappings for ansible04–07 |
| DNS | `homelab.internal` hostname entries from `dns_records` |

## DNS entries

| FQDN | IP | Service |
|------|----|---------|
| `monitoring.homelab.internal` | 192.168.100.40 | k8s MetalLB VIP — monitoring |
| `observability.homelab.internal` | 192.168.100.41 | k8s MetalLB VIP — observability |
| `argocd.homelab.internal` | 192.168.100.42 | k8s MetalLB VIP — ArgoCD |
| `ca.homelab.internal` / `pki.homelab.internal` | 192.168.100.13 | step-ca / portal |
| `ansible05/06/07.homelab.internal` | 192.168.100.15/16/17 | k8s nodes |

## Firewall

The CachyOS host UFW must allow DHCP (udp/67) and DNS (udp+tcp/53) on the
bridge plus route/NAT rules. Restore after UFW resets with
`scripts/ufw-libvirt.sh`.[^cloud-kvm-doc] The libvirt role also manages these
rules.

## Management

```bash
virsh net-list                      # from the CachyOS host
virsh net-dhcp-leases ansible-net   # active leases
```

[^vm-doc]: VM documentation — network section
[^cloud-kvm-doc]: Cloud images in KVM — NAT bridge diagram, UFW rules, dnsmasq
