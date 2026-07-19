#!/usr/bin/env bash
set -euo pipefail

IFACE="virbr-ansible"

echo "Configuring UFW rules for libvirt network on ${IFACE}..."

# Allow DHCP and DNS from VMs on the bridge
ufw allow in on "${IFACE}" to any port 67 proto udp comment "libvirt DHCP"
ufw allow in on "${IFACE}" to any port 53 proto udp comment "libvirt DNS"
ufw allow in on "${IFACE}" to any port 53 proto tcp comment "libvirt DNS TCP"

# Allow all forwarded traffic between VMs on the bridge
ufw route allow in on "${IFACE}" out on "${IFACE}" comment "libvirt guest cross-traffic"

# Allow forwarded traffic from VMs to external interfaces
for ext_if in $(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(en|wl)' | grep -v "${IFACE}"); do
    ufw route allow in on "${IFACE}" out on "${ext_if}" comment "libvirt NAT out via ${ext_if}"
done

echo "UFW rules applied. Current status:"
ufw status numbered | grep -A1 -B1 "${IFACE}"
