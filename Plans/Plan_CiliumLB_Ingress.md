# Plan: Replace MetalLB + ingress-nginx with Cilium native LB + Cilium ingress

## Goal

Retire MetalLB (helm `metallb-0.14.9`) and ingress-nginx (helm
`ingress-nginx-4.12.3`). Cilium (helm `cilium-1.18.0`, already native
routing) provides LoadBalancer VIPs via `CiliumLoadBalancerIPPool` +
`CiliumL2AnnouncementPolicy` and HTTP ingress via its Envoy-based
`cilium` IngressClass.

## Current state (verified 2026-08-05)

- Single LB Service: `ingress-nginx/ingress-nginx-controller`
  LoadBalancer → `192.168.100.42` (IPPool `homelab`
  192.168.100.40-49, L2Advertisement). Only LB service in cluster.
- Single IngressClass: `nginx` (`k8s.io/ingress-nginx`).
- Ingresses:
  - `monitoring` (kube-prometheus-stack helm, `ingressClassName: nginx`):
    grafana `/grafana`, prometheus `/prometheus`, alertmanager
    `/alertmanager` — plain paths, apps handle subpaths via own config
    (`root_url`, `route-prefix`). **Portable as-is.**
  - `observability/observability-kibana` (`cluster/base/observability/ingress.yaml`):
    nginx-only `rewrite-target: /$2` + `use-regex` regex capture groups
    (kibana + ES). `observability-elasticsearch` ingress **removed** (no
    consumers; Cilium 1.18 has no rewrite annotation).
- TLS via cert-manager ClusterIssuer `step-ca` (controller-agnostic).
- MetalLB, ingress-nginx, cert-manager, cilium are all **helm-managed**
  from ansible05 (NOT ArgoCD). Monitoring/observability apps are ArgoCD.

## Feature/functionality impact

| Component | Impact | Action |
|-----------|--------|--------|
| Monitoring ingresses | None | `ingressClassName: nginx` → `cilium` |
| cert-manager step-ca | None | unchanged |
| LB VIP `.42` | None (client-visible) | pool + L2 policy, fixed IP annotation |
| ES `/elasticsearch` | **Remove** | no live consumers (in-cluster otel ships to `observability-es-http:9200` direct; VM otel is dead code — `otel` group empty). ES has no basePath support, Cilium has no rewrite |
| Kibana `/kibana` | Minor | ImplementationSpecific regex → `pathType: Prefix` (kibana `server.basePath=/kibana` + `rewriteBasePath` handles it, no rewrite needed) |
| ingress-nginx metrics (10254) | Lost | Envoy metrics instead (optional ServiceMonitor later) |

## Tasks

- [x] **Repo: LB CRDs** — `CiliumLoadBalancerIPPool` `homelab-pool`
      (blocks start/stop from `cilium_lb_pool`) +
      `CiliumL2AnnouncementPolicy` `homelab` (`interfaces: [enp1s0]`,
      `loadBalancerIPs: true`, no serviceSelector → all LB services) via
      `roles/kubernetes/templates/cilium-lb.yaml.j2` + kubectl apply task
      (rendered to `/etc/kubernetes/cilium/`).
- [x] **Repo: Cilium helm values** — `roles/kubernetes/defaults/main.yml`
      + matching `--set` args in `tasks/main.yml`:
      - `ingressController.enabled=true`, `default=true`
      - `ingressController.loadbalancerMode=shared`
      - `ingressController.service.type=LoadBalancer`
      - fixed VIP via Service annotation **`lbipam.cilium.io/ips`**
        (verified key + `--set "…\.cilium\.io/ips=…"` helm escaping in 1.18;
        `kubernetes_cilium_ingress_vip` var, default `ingress_vip` — override
        `-e kubernetes_cilium_ingress_vip=192.168.100.43` for temp validation)
      - `l2announcements.enabled=true`
- [x] **Rework observability ingresses** (`cluster/base/observability/ingress.yaml`):
      ES ingress **removed** (no consumers, no rewrite support); kibana →
      `ingressClassName: cilium`, `pathType: Prefix`, path `/kibana`, nginx
      regex/rewrite annotations dropped.
- [x] **Monitoring** (`cluster/base/monitoring/values.yaml`): 3 ingresses
      `ingressClassName: nginx` → `cilium`.
- [x] **Argocd + longhorn** (`cluster/base/argocd/values.yaml`,
      `cluster/base/longhorn/values.yaml`): `ingressClassName: nginx` →
      `cilium`, drop `nginx.ingress.kubernetes.io/ssl-redirect` annotation.
- [x] **Var cleanup**: `metallb_pool` → `cilium_lb_pool`
      (`group_vars/k8s/main.yml`); dropped `metallb_version` +
      `ingress_nginx_version` (`group_vars/all/main.yml`).
- [ ] **Lint + plan check**: `ansible_lint` role/playbooks; review via
      ArgoCD/kustomize dry-run.
- [ ] **Apply cilium ingress on temp VIP `.43` first** (validation):
      `helm upgrade cilium` with `ingressController` enabled but Service on
      `.43` (annotation override); wait ds/operator rollout; confirm
      `cilium-envoy` DaemonSet up; `kubectl get ingressclass`, `kubectl get
      svc -n kube-system` for ingress Service EXTERNAL-IP `.43`.
- [ ] **Validate all apps via `.43`** (host `--resolve`/`/etc/hosts`):
      argocd, longhorn, grafana `/grafana`, prometheus `/prometheus`,
      alertmanager `/alertmanager`, kibana `/kibana` (ES direct
      `observability-es-http:9200` still serves otel collector). Confirm
      cert-manager TLS still 200, SAN ok.
- [ ] **Cutover to `.42`** (short blip): set cilium ingress Service to `.42`
      (release temp `.43`), verify `.42` serves all apps; confirm ARP/NDP
      announced by Cilium (no MetalLB conflict while nginx still owns `.42`
      — sequence below).
- [ ] **Uninstall ingress-nginx**: `helm uninstall ingress-nginx -n
      ingress-nginx`; delete ns. Remove `nginx` IngressClass. Requires
      holding `.42` → do AFTER cilium ingress claims `.42`; expect brief
      outage on `.42` between nginx release and cilium re-IP.
- [ ] **Uninstall MetalLB**: `helm uninstall metallb -n metallb-system`;
      delete ns; remove `metallb`/`metallb-system` resources + Pool/L2 CRDs.
- [ ] **Verify final state**: `.42:80/443` → all ingress hosts 200/expected;
      NodePort + cross-node pod paths still OK; cilium status healthy;
      `helm ls` no metallb/ingress-nginx; `kubectl get ingress -A` all
      IngressClass `cilium`.
- [ ] **Cleanup repo**: remove `cluster/base/metallb/`,
      `cluster/base/ingress-nginx/` (vars already dropped/renamed); update
      docs.
- [ ] **Docs/knowledge/changelog**: `knowledge/log.md` entry, CHANGELOG
      `### Changed` + `### Removed`, update Plan_k8s references; `okf.py
      check`; commit-release on request.

## Cutover sequence (avoid IP collision on L2)

1. Cilium ingress on `.43` (test) — MetalLB still on `.42`, no ARP clash.
2. Validate everything on `.43`.
3. `helm uninstall ingress-nginx` (releases `.42`; `.42` down briefly).
4. Re-IP cilium ingress Service to `.42` (helm values/annotation) — cilium
   L2 announcement takes `.42`.
5. `helm uninstall metallb` (no LB services left).
6. Remove CRDs/namespaces, repo cleanup.

## Rollback

- Restore ingress-nginx + metallb (helm reinstall, keep `cluster/base/`
  values in git until fully removed), point ingresses back to
  `ingressClassName: nginx`, cilium helm values revert (ingressController
  disabled, l2announcements disabled). `.42` returns to nginx LB Service.

## Risks / notes

- ~~Envoy rewrite semantics~~ — ES `/elasticsearch` route removed (no
  consumers); Cilium forwards paths verbatim (no rewrite annotation in 1.18).
- Fixed VIP annotation **verified live**: `lbipam.cilium.io/ips`
  (comma-separated list); ingress annotations propagate to generated LB
  Service via `ingressLBAnnotationPrefixes`; also settable directly on
  shared `cilium-ingress` Service via helm `ingressController.service.annotations`.
- ingress-nginx admission webhook must be removed before ns deletion.
- Envoy daemonset adds memory/cpu to each node; L2 announcement only
  answers ARP for the VIP (no takeover of unrelated IPs).
- Longhorn/argocd ingresses live in Helm charts — classes flipped to
  `cilium` in `cluster/base/{longhorn,argocd}/values.yaml`.
- `metallb_pool` → `cilium_lb_pool` rename done
  (`group_vars/k8s/main.yml`); used by `cilium-lb.yaml.j2`.
