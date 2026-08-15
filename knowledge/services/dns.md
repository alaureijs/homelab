---
type: Service
title: Unbound DNS
description: Recursive DNS resolver on ansible04 serving homelab.internal zones with DNSSEC.
resource: udp://192.168.100.13:53
tags: [dns, unbound, dnssec]
status: stable
sources:
  - id: pki-doc
    resource: ../../docs/pki-step-ca.md
    title: step-ca documentation (DNS section)
    last_modified: 2026-07-31
generated:
  by: human:alaureijs
  at: 2026-08-01T13:30:00Z
verified:
  - by: human:alaureijs
    at: 2026-08-01T13:30:00Z
---

## Runtime

- Unbound on [/infrastructure/ansible04.md](/infrastructure/ansible04.md),
  the DHCP nameserver all VMs receive via the libvirt network.
- Records defined in `dns_records`
  (`inventory/group_vars/all/main.yml`), rendered by
  `roles/dns/templates/local-zones.conf.j2` — each entry gets a
  `local-zone` (NXDOMAIN for unknown names) + `local-data` A record.
- DNSSEC: validator+iterator modules, root trust anchor in
  `/var/lib/unbound/root.key`, `harden-dnssec-stripped: yes`.

## Resolution order

1. `homelab.internal` local zones first
2. FQDNs (containing a dot) forwarded upstream (1.1.1.1, 8.8.8.8)
3. Bare hostnames resolve from local zones only — otherwise NXDOMAIN, **no
   forwarding**

## Management

```bash
unbound-checkconf /etc/unbound/unbound.conf
unbound-control reload
dig @192.168.100.13 monitoring.homelab.internal
dig @192.168.100.13 github.com +dnssec   # expect AD flag
```

Records for the retired Podman stack (harbor/ansible01-03 → .10/.11/.12)
were removed when the lab was torn down; `monitoring.homelab.internal`,
`argocd.homelab.internal` and
`longhorn.homelab.internal` all point at the single k8s Traefik ingress
VIP (.42, MetalLB Layer2, SNI-based routing), with the k8s nodes
ansible05/06/07/08 → .15/.16/.17/.18.

[^pki-doc]: step-ca documentation — DNS architecture, forwarding behavior, DNSSEC
