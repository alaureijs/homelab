# Plan: Replace Observability (ECK → Loki) + GitLab

Replace in-cluster ECK observability (ES 9.4.4, Kibana, otel-collector DS)
with Loki + Promtail on the monitoring stack, and deploy GitLab with a
bundled registry for container distribution. Add a GitLab-hosted
`monitoring-content` repo for Prometheus rules / Grafana dashboards /
Alertmanager routing.

Status: P1 complete (commits 92b6756, 4a47175). P2 in progress.

## P1 — Remove observability stack [DONE]
- [x] Delete `cluster/apps/observability.yaml` + `cluster/base/observability/`
- [x] Remove `observability` from `cluster/apps/namespaces.yaml` +
      `cluster/base/argocd/values.yaml` `application.namespaces`
- [x] Commit+push (92b6756); force-refresh bootstrap; verify teardown
      (ns + 50Gi PVC gone, PV Released, ES pod force-deleted)
- [x] DNS: remove observability + observability-es from `dns_records`
- [x] Vault: prune `vault_elasticsearch_password` + `vault_kibana_password`
- [x] Docs + knowledge cleanup (4a47175): k8s-secrets.md, sops.md,
      ansible-mcp.md, opencode.json (ES MCP removed), network.md, dns.md,
      guides/index.md, log.md, CHANGELOG.md; okf.py check clean, ansible-lint
      production profile green

## P2 — Loki + Promtail + node exporter [COMPLETE]
- [x] Enable `nodeExporter.enabled: true` in monitoring values (node metrics
      for all 4 VMs; containers already covered via kubelet/cAdvisor)
- [x] Fix node-exporter host 9100 conflict: VM systemd node_exporter (mTLS,
      `192.168.100.x:9100`) collides with KPS DaemonSet `hostNetwork: true`.
      Commit `d460bee` + `8338223` (correct passthrough key
      `prometheus-node-exporter.hostNetwork: false`). Live DS patched to break
      the stuck auto-sync health wait; app converged Synced/Healthy at
      `8338223`; 4/4 pods Running; Prometheus `node-exporter` job all up.
      NOTE: `nodeExporter.hostNetwork` is NOT wired to the subchart — must use
      `prometheus-node-exporter.hostNetwork`.
- [ ] Create `cluster/base/loki/values.yaml` (Monolithic, replication 1,
      filesystem storage, ~20Gi Longhorn PVC, caches/canary/minio off)
- [ ] Create `cluster/base/loki/promtail-values.yaml` (DaemonSet, on all nodes)
- [ ] Create `cluster/apps/loki.yaml` (multi-source: loki 17.x +
      promtail 6.17.1 @ grafana-community.github.io/helm-charts + `$values`)
- [ ] Add `loki` to `cluster/apps/namespaces.yaml`
- [x] Commit+push; force-refresh bootstrap; verify loki pods on all 4 nodes,
      `:3100/ready` OK, promtail pods present
- [x] Add Grafana datasource (`additionalDataSources` → `http://loki-gateway:3100`)
      in `cluster/base/monitoring/values.yaml`; sync; verify in Explore
- [x] Verify Loki end-to-end: promtail push 204 (was 401 — Loki `auth_enabled: true`
      default; fixed `loki.auth_enabled: false`, commit `fe39410`), labels via
      `loki-gateway/loki/api/v1/labels` OK, query_range returns streams

## P3 — Prune default dashboards [COMPLETE]
- [x] Set `grafana.defaultDashboardsEnabled: false`; verify 22
      `monitoring-kube-prometheus-*` ConfigMaps pruned (commit `7da9fb7`).
      NOTE: first sync op=Failed on CRD "metadata.annotations Too long" (>256KB,
      ArgoCD last-applied bloat on coreos CRDs) — transient; selfHeal re-sync
      Succeeded, app Healthy/Synced, 0 CRD failures.

## P4 — GitLab
- [ ] DNS: add `gitlab.homelab.internal` + `registry.gitlab.homelab.internal`
      → .42 to `dns_records`
- [ ] Create `cluster/base/gitlab/values.yaml` — chart 10.2.2
      (gitlab/gitlab @ charts.gitlab.io, app v19.2.2). Bundled
      postgres/redis/MinIO REMOVED in 10.x (issue 6271) → external:
      `global.psql.host`/`global.redis.host` + `password.useSecret`; object
      storage via MinIO: `global.appConfig.object_store.enabled: true` +
      `connection` S3 secret (lfs=git-lfs, artifacts=gitlab-artifacts,
      uploads=gitlab-uploads, packages=gitlab-packages) + registry
      `storage: {secret: gitlab-registry-storage}` (S3). Ingress:
      `global.ingress.enabled: true` + `gatewayApi.enabled: false` +
      `installEnvoy: false` + `class: traefik` (classic Ingress renders; NO
      nginx-ingress subchart) + pre-created step-ca `Certificate gitlab-tls`
      via `global.ingress.tls.secretName`; `certmanager.installCertmanager:
      false`; `prometheus.install: false`; `gitlab-runner.install: true`;
      `gitlab-zoekt.install: false`; kas per values; Longhorn SC + node
      affinity ansible08; hosts gitlab + registry.gitlab.homelab.internal
- [ ] Create `cluster/base/gitlab/bitnami/` — bitnami/postgresql 18.8.9
      (Longhorn SC, auth secret, ~1-2Gi) + bitnami/redis 28.0.5 (standalone,
      auth) + bitnami/minio 17.0.21 (standalone mode, `persistence.size`
      10Gi Longhorn, `auth.existingSecret`) as separate base apps
- [ ] Create `cluster/base/gitlab/secrets/` (`gitlab-initial-root-password.sops.yaml`,
      step-ca `Certificate gitlab-tls`, `gitlab-registry-storage` S3 secret,
      `gitlab-object-store` connection secret, `ksops.yaml`, `kustomization.yaml`)
      mirroring `cluster/base/monitoring/secrets/`
- [ ] Create `cluster/base/postgresql/`, `cluster/base/redis/`, `cluster/base/minio/`
      (bitnami charts, Longhorn SC, auth `existingSecret`); create
      `cluster/apps/{gitlab,postgresql,redis,minio}.yaml` + `gitlab` in namespaces.yaml
- [ ] Commit+push; sync; headroom check (`kubectl top nodes` before/after);
      verify `gitlab.homelab.internal` sign_in 200 +
      `docker login registry.gitlab.homelab.internal`

## P5 — monitoring-content repo
- [ ] Create GitLab repo `monitoring-content` (rules/ PrometheusRule CRs,
      dashboards/ JSON→ConfigMaps, alertmanager/ SOPS secret with
      `alertmanager.yaml` key, root kustomization.yaml)
- [ ] Set `alertmanager.alertmanagerSpec.configFromSecret` in monitoring
      values; create `cluster/apps/monitoring-content.yaml` (kustomize,
      prune+selfHeal, pattern of `monitoring-secrets.yaml`)

## P6 — Final verify
- [ ] `kubectl get app -A` all Synced/Healthy; node pressure OK
- [ ] ansible-lint + `scripts/okf.py check`; CHANGELOG + knowledge log

## Decisions
- GitHub stays as ArgoCD source; GitLab hosts the `monitoring-content` repo
- Containers in GitLab registry (no Harbor)
- MinIO kept (registry/artifacts object storage, ~256Mi/10Gi PVC)
- gitlab-runner enabled
- Promtail DaemonSet; Loki monolithic + filesystem storage on Longhorn
- Default Grafana dashboards removed
- monitoring-content: PrometheusRule CRs need label
  `app.kubernetes.io/instance: kube-prometheus-stack`; dashboard CMs need
  `grafana_dashboard=1` sidecar label; Alertmanager via `configFromSecret`

## Rollback
- P2: revert loki.yaml + namespaces; re-add observability.yaml (previous ECK
  state in git history 92b6756^)
- P4: revert gitlab.yaml + namespaces + dns_records; uninstall via ArgoCD prune
