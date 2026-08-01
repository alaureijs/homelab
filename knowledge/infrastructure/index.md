# Asset

* [sdb storage pool](storage.md) - Directory-backed libvirt storage pool holding VM disks and cloud-init ISOs.

# Guide

* [Cloud-init provisioning](cloud-init.md) - NoCloud first-boot configuration applied to every libvirt VM.

# Network

* [ansible-net](network.md) - NAT virtual network on the CachyOS host bridging VMs to the LAN.

# Virtual Machine

* [ansible01](ansible01.md) - Harbor registry host (192.168.100.10), Rocky Linux 10.2 under libvirt.
* [ansible02](ansible02.md) - Monitoring stack host (192.168.100.11), Rocky Linux 10.2 under libvirt.
* [ansible03](ansible03.md) - ELK logging stack host (192.168.100.12), Rocky Linux 10.2 under libvirt.
* [ansible04](ansible04.md) - PKI, DNS, and portal host (192.168.100.13), Rocky Linux 10.2 under libvirt.
