---
type: Guide
title: Kubernetes secrets inventory
description: Catalog of every Secret in the cluster — SOPS-committed files vs runtime-generated (ECK, Helm, cert-manager) — and how to read each one.
tags: [secrets, kubernetes, sops, cert-manager, eck, argocd]
status: stable
sources:
  - id: k8s-secrets-doc
    resource: ../../docs/k8s-secrets.md
    title: Kubernetes Secrets documentation
    last_modified: 2026-08-06
generated:
  by: human:alaureijs
  at: 2026-08-06T12:00:00Z
verified:
  - by: human:alaureijs
    at: 2026-08-06T12:00:00Z
---

## Two sources of secrets

- **SOPS-committed** in `cluster/` — read with `sops --decrypt`; ArgoCD
  ksops plugin applies them at sync.
- **Runtime-generated** (ECK, Helm, cert-manager) — exist only in the live
  cluster; read with `kubectl`, no repo copy.

Cluster access: `ssh root@192.168.100.15` with
`export KUBECONFIG=/etc/kubernetes/super-admin.conf`.

## SOPS-committed secrets

| Secret | File |
|--------|------|
| `grafana-admin` (monitoring) | `cluster/base/monitoring/secrets/grafana-admin.sops.yaml` |
| `argocd-admin-password` | `cluster/secrets/argocd-admin-password.yaml` |
| `argocd-repo-ssh-key` | `cluster/secrets/argocd-repo-ssh-key.yaml` |
| `argocd-sops-age-key` | `cluster/secrets/argocd-sops-age-key.yaml` |

`grafana-admin` is wired through the `monitoring-secrets` Application
(ksops kustomize). The three `cluster/secrets/` argocd Secrets are applied
manually at bootstrap (not referenced by any Application manifest); the
live ArgoCD admin hash comes from `argocdServerAdminPassword` in
`cluster/base/argocd/values.yaml`, whose plaintext equals the SOPS value.

## cert-manager TLS secrets

Issued by ClusterIssuer `step-ca` into runtime tls Secrets; Certificate CRs:

| Secret | Namespace |
|--------|-----------|
| `argocd-server-tls` | argocd |
| `monitoring-tls` | monitoring |
| `observability-tls` | observability |
| `longhorn-ui-tls` | longhorn-system |

## ECK secrets (observability)

Runtime-only: `observability-es-elastic-user` (elastic superuser password,
consumed by otel-collector), `observability-kibana-user`, ES internal CA /
certs (`*-ca-internal`, `*-certs-*`), file realm, config secrets.

## Helm/Cilium runtime secrets

kube-prometheus-stack (web config, TLS assets in `monitoring`), Cilium
(`cilium-ca`, `hubble-server-certs` in `kube-system`), Longhorn webhooks.

`sh.helm.release.v1.*` entries are Helm release records, not credentials.

## Reading commands

```bash
sops --decrypt cluster/base/monitoring/secrets/grafana-admin.sops.yaml

kubectl get secret -n observability observability-es-elastic-user \
  -o jsonpath='{.data.elastic}'

kubectl get secret -n monitoring monitoring-tls \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout \
  -subject -dates -ext subjectAltName
```
