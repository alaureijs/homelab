---
type: Service
title: step-ca
description: Private online certificate authority on ansible04 issuing 30-day certificates.
resource: https://ca.homelab.internal:9000
tags: [pki, certificates, step-ca]
status: stable
sources:
  - id: pki-doc
    resource: ../../docs/pki-step-ca.md
    title: step-ca documentation
    last_modified: 2026-07-31
generated:
  by: human:alaureijs
  at: 2026-08-01T13:30:00Z
verified:
  - by: human:alaureijs
    at: 2026-08-01T13:30:00Z
---

## Runtime

- step-ca v0.30.2 (Podman container via `podman kube play`), HTTPS on `:9000`
  bound to `127.0.0.1`; CLI `step-cli` v0.30.6 on all hosts.
- Storage: `/var/lib/step-ca` (PV/PVC, 20 GB disk).
- Provisioners: **JWK** (admin API, used by Ansible) + **ACME**
  (automated issuance, directory at `https://pki.homelab.internal/acme/acme/directory`).

## Certificates

All infra certs (host identity, Harbor, monitoring, ELK, node-exporter
server + mTLS client, portal/packages/documents vhosts) are issued here with
30-day duration and auto-renewal within 30 days of expiry. The `certificates`
role regenerates on expiry threshold; force with
`certificates_force_renewal=true`.[^pki-doc]

## Backup

Root CA private key backed up to the controller in `files/step-ca/`
(vault-encrypted). Restore: `step_ca_restore=true` on provisioning.

## Clients

```bash
step ca bootstrap --ca-url https://ca.homelab.internal:9000 --fingerprint <fp> --install
step ca certificate "harbor.homelab.internal" harbor.crt harbor.key
```

[^pki-doc]: step-ca documentation — architecture, cert types, renewal, backup, troubleshooting
