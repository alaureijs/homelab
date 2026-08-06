# Kubernetes Secrets

Catalog of every Secret in the cluster, what it is, and how to read it.
Secrets come from two sources: **SOPS-committed files** in this repo (applied
by ArgoCD or manually) and **runtime-generated Secrets** (ECK, Helm charts,
cert-manager) that exist only in the live cluster.

Cluster access: `ssh root@192.168.100.15` (or any node) with
`export KUBECONFIG=/etc/kubernetes/super-admin.conf`.

## Quick lookup

| Secret | Namespace | Type | Where it lives | How to read |
|--------|-----------|------|----------------|-------------|
| `grafana-admin` | monitoring | Opaque | `cluster/base/monitoring/secrets/grafana-admin.sops.yaml` (SOPS) | `sops --decrypt <file>` |
| `argocd-admin-password` | argocd | Opaque | `cluster/secrets/argocd-admin-password.yaml` (SOPS) | `sops --decrypt <file>` |
| `argocd-repo-ssh-key` | argocd | Opaque | `cluster/secrets/argocd-repo-ssh-key.yaml` (SOPS) | `sops --decrypt <file>` |
| `argocd-sops-age-key` | argocd | Opaque | `cluster/secrets/argocd-sops-age-key.yaml` (SOPS) | `sops --decrypt <file>` |
| `argocd-secret` | argocd | Opaque | runtime (ArgoCD) | `kubectl get secret -n argocd argocd-secret -o jsonpath='{.data}'` |
| `argocd-notifications-secret` | argocd | Opaque | runtime (ArgoCD) | `kubectl get secret -n argocd ...` |
| `argocd-redis` | argocd | Opaque | runtime (ArgoCD HA) | `kubectl get secret -n argocd argocd-redis -o jsonpath='{.data}'` |
| `argocd-server-tls` | argocd | tls | cert-manager (ClusterIssuer `step-ca`) | cert pipeline (below) |
| `step-ca-acme-key` | cert-manager | Opaque | runtime (ACME account key) | `kubectl get secret -n cert-manager step-ca-acme-key -o jsonpath='{.data}'` |
| `cert-manager-webhook-ca` | cert-manager | Opaque | runtime | `kubectl get secret -n cert-manager ...` |
| `longhorn-ui-tls` | longhorn-system | tls | cert-manager (`step-ca`) | cert pipeline (below) |
| `longhorn-webhook-ca` / `longhorn-webhook-tls` | longhorn-system | tls | runtime (Longhorn webhooks) | `kubectl get secret -n longhorn-system ...` |
| `monitoring-tls` | monitoring | tls | cert-manager (`step-ca`) | cert pipeline (below) |
| `prometheus-*-prometheus-*` | monitoring | Opaque | runtime (kube-prometheus-stack) | `kubectl get secret -n monitoring ...` |
| `alertmanager-*-alertmanager-*` | monitoring | Opaque | runtime (kube-prometheus-stack) | `kubectl get secret -n monitoring ...` |
| `observability-es-elastic-user` | observability | Opaque | runtime (ECK) | `kubectl get secret -n observability ...` |
| `observability-kibana-user` | observability | Opaque | runtime (ECK) | `kubectl get secret -n observability ...` |
| `observability-*` (ES/Kibana internal) | observability | Opaque | runtime (ECK) | `kubectl get secret -n observability ...` |
| `observability-tls` | observability | tls | cert-manager (`step-ca`) | cert pipeline (below) |
| `cilium-ca` / `hubble-server-certs` | kube-system | Opaque/tls | runtime (Cilium) | `kubectl get secret -n kube-system ...` |

`sh.helm.release.v1.*` entries are Helm release records (not credentials).

## SOPS-committed secrets

Four Secrets have committed SOPS-encrypted copies in `cluster/`. Read them
with `sops --decrypt` on the controller (age key at
`~/.config/sops/age/keys.txt`); ArgoCD's ksops plugin does the same at sync
time.

### Grafana admin

- **File**: `cluster/base/monitoring/secrets/grafana-admin.sops.yaml`
- **Applied by**: `monitoring-secrets` Application (ArgoCD, ksops kustomize generator)
- **Consumed by**: kube-prometheus-stack Grafana via `existingSecret: grafana-admin` (`cluster/base/monitoring/values.yaml`)

```bash
sops --decrypt cluster/base/monitoring/secrets/grafana-admin.sops.yaml
#   admin-user / admin-password keys
```

### ArgoCD admin password

- **File**: `cluster/secrets/argocd-admin-password.yaml`
- **Applied by**: manual `kubectl apply -f -` during bootstrap (not wired into any ArgoCD Application)
- **Consumed by**: nothing at runtime — the live admin hash comes from the `argocdServerAdminPassword` bcrypt value in `cluster/base/argocd/values.yaml`. The SOPS plaintext is the same password (`DBEVGjsQPRYAsJehyWuEW3ex`); it matches the bcrypt hash and is what you log in with.

```bash
sops --decrypt cluster/secrets/argocd-admin-password.yaml | kubectl apply -f -
# data.password holds the base64 admin password
```

### ArgoCD repo SSH key

- **File**: `cluster/secrets/argocd-repo-ssh-key.yaml`
- **Applied by**: manual `kubectl apply -f -` during bootstrap
- **Consumed by**: ArgoCD repoServer for `git@github.com:alaureijs/homelab.git`

```bash
sops --decrypt cluster/secrets/argocd-repo-ssh-key.yaml | kubectl apply -f -
```

### ArgoCD SOPS age key

- **File**: `cluster/secrets/argocd-sops-age-key.yaml`
- **Applied by**: manual `kubectl apply -f -` during bootstrap
- **Consumed by**: ArgoCD repoServer (SOPS plugin) via
  `cluster/base/argocd/values.yaml` (mounts `argocd-sops-age-key`,
  sets `SOPS_AGE_KEY_FILE`)

```bash
sops --decrypt cluster/secrets/argocd-sops-age-key.yaml | kubectl apply -f -
```

## cert-manager TLS secrets (step-ca)

All inbound TLS is issued by cert-manager against the `step-ca`
ClusterIssuer (smallstep CA on ansible04). These Secrets are runtime objects
generated by the cert-manager Certificate CRs, not committed:

| Secret | Namespace | Certificate CR |
|--------|-----------|----------------|
| `argocd-server-tls` | argocd | `argocd-server-tls` |
| `monitoring-tls` | monitoring | `monitoring-tls` |
| `observability-tls` | observability | `observability-tls` |
| `longhorn-ui-tls` | longhorn-system | `longhorn-ui-tls` |

Inspect without writing to disk:

```bash
kubectl get secret -n monitoring monitoring-tls \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout \
  -subject -dates -ext subjectAltName
```

For renewals, force via cert-manager or see `docs/pki-step-ca.md`.

## ECK-managed secrets (observability)

Elastic Cloud on Kubernetes generates credentials and internal TLS
automatically. These do not exist in the repo — read them live:

```bash
# elastic superuser password (used by otel-collector via ELASTIC_PASSWORD)
kubectl get secret -n observability observability-es-elastic-user \
  -o jsonpath='{.data.elastic}'

# Kibana system user
kubectl get secret -n observability observability-kibana-user \
  -o jsonpath='{.data}'

# ES internal CA + certs (http/transport), file realm, config
kubectl get secret -n observability observability-es-http-ca-internal -o yaml
```

If rotated, the otel-collector DaemonSet picks up the new value on restart.

## kube-prometheus-stack secrets (monitoring)

Helm-generated — Prometheus/Alertmanager web config, TLS assets, and admin
secrets. Read live:

```bash
kubectl get secret -n monitoring alertmanager-monitoring-kube-prometheus-alertmanager-web-config -o yaml
kubectl get secret -n monitoring prometheus-monitoring-kube-prometheus-prometheus-web-config -o yaml
```

## Cilium secrets (kube-system)

`cilium-ca` (internal CA) and `hubble-server-certs` (Hubble UI/relay TLS).
Read live, no repo copy.

## Backing a live secret into the repo

```bash
kubectl get secret -n <ns> <name> -o yaml > cluster/base/<app>/secrets/<name>.sops.yaml
sops --encrypt --in-place cluster/base/<app>/secrets/<name>.sops.yaml
sops --decrypt cluster/base/<app>/secrets/<name>.sops.yaml   # sanity check
```

See `docs/sops.md` for the full workflow.
