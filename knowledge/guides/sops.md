---
type: Guide
title: SOPS secrets
description: Working with SOPS+age encrypted secrets in cluster/ — decrypt, encrypt, edit, add age keys, and read TLS certs from cert-manager Secrets.
tags: [sops, age, secrets, encryption, certs]
status: stable
sources:
  - id: sops-doc
    resource: ../../docs/sops.md
    title: SOPS secrets documentation
    last_modified: 2026-08-05
generated:
  by: human:alaureijs
  at: 2026-08-05T15:00:00Z
verified:
  - by: human:alaureijs
    at: 2026-08-05T15:00:00Z
---

## Setup

- `.sops.yaml` at repo root: encrypts `data`/`stringData` of any
  `cluster/*.y(a)ml` file with the age public key
  `age1vhsg9zcjsyhzqxvaj9rmkwva27ur0s3ymunxfxx2e2vlr2m26aps3vfa98`.
- Controller: `sops` + `age` installed, private key in
  `~/.config/sops/age/keys.txt` (auto-detected, no env var).
- Cluster: ArgoCD ksops plugin (v4.5.1) decrypts at sync; SOPS age key from
  the `argocd-sops-age-key` Secret, `SOPS_AGE_KEY_FILE` set.

## Reading secrets

```bash
sops --decrypt cluster/base/monitoring/secrets/grafana-admin.sops.yaml
sops --edit cluster/base/monitoring/secrets/grafana-admin.sops.yaml
sops --encrypt --in-place cluster/base/monitoring/secrets/grafana-admin.sops.yaml
```

Decrypted output pipes straight into `kubectl apply -f -` — plaintext never
written to disk.

## Reading TLS certs

cert-manager stores issued certs in k8s Secrets (`tls.crt`, `tls.key`,
`ca.crt`), e.g. `monitoring-tls`. Inspect without writing to disk:

```bash
kubectl get secret -n monitoring monitoring-tls \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout \
  -subject -dates -ext subjectAltName
```

Certs exported into a committed `cluster/` Secret are read by decrypting
first (`sops --decrypt <file>`), then base64-decoding `tls.crt` through
`openssl x509`. Full backup/restore workflow in [the doc][^sops-doc].

[^sops-doc]: SOPS secrets documentation — cert backup, age key rotation, troubleshooting
