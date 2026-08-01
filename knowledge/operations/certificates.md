---
type: Guide
title: Certificate lifecycle
description: How TLS and mTLS certificates are issued, renewed, and trusted across the lab.
tags: [certificates, tls, mtls, step-ca]
status: stable
sources:
  - id: pki-doc
    resource: ../../docs/pki-step-ca.md
    title: step-ca documentation
    last_modified: 2026-07-31
  - id: monitoring-doc
    resource: ../../docs/monitoring.md
    title: Monitoring documentation (mTLS section)
    last_modified: 2026-07-31
generated:
  by: human:alaureijs
  at: 2026-08-01T14:30:00Z
verified:
  - by: human:alaureijs
    at: 2026-08-01T14:30:00Z
---

## Issuance

All certificates come from [/services/step-ca.md](/services/step-ca.md) with
30-day duration: host identity, service vhosts (Harbor, monitoring, ELK,
portal/packages/documents), node-exporter server certs, and the Prometheus
mTLS client cert. The [certificates role](/roles/certificates.md) regenerates
within 30 days of expiry.[^pki-doc]

## Renewal

```bash
# force renewal for a host
ansible-playbook playbooks/provision-ansible0X.yml -e certificates_force_renewal=true
# check expiry
step certificate inspect /etc/pki/tls/certs/harbor.crt --short
```

## mTLS (node-exporter / ELK ingress)

- Node-exporter scraping: shared mTLS CA + server certs per host + client
  cert/key for Prometheus, under `/etc/prometheus/mtls/`; dirs `0755`/files
  `0644`, SELinux `container_file_t`.[^monitoring-doc]
- ELK ingress: per-host client certs in `/etc/otel-client/`; after cert
  renewal re-run `provision-otel.yml` to restore `0644` on the key.

## Trust

Root CA in the system trust store on all hosts (`step-ca.crt` in
ca-trust anchors). nginx enforces OCSP stapling and TLS 1.3 only.

[^pki-doc]: step-ca documentation — certificate types, renewal, client bootstrap
[^monitoring-doc]: Monitoring documentation — mTLS layout and permissions
