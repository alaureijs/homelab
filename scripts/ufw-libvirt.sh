#!/usr/bin/env bash
set -euo pipefail

IFACE="virbr-ansible"

echo "Configuring UFW rules for libvirt network on ${IFACE}..."

# Allow all incoming traffic on the bridge (DHCP, DNS, etc.)
ufw route allow in on "${IFACE}" out on "${IFACE}" comment "libvirt guest cross-traffic"

# Allow forwarded traffic from VMs to external interfaces
for ext_if in $(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(en|wl)' | grep -v "${IFACE}"); do
    ufw route allow in on "${IFACE}" out on "${ext_if}" comment "libvirt NAT out via ${ext_if}"
done

echo "UFW rules applied. Current status:"
ufw status numbered | grep -A1 -B1 "${IFACE}"
