# Plan: Calico + MetalLB + Traefik Migration

- Status: Phase 4 complete (migration done, cleanup verified)
- Date: 2026-08-14
- Scope: Replace Cilium CNI on k8s cluster (k8s.homelab.internal) with
  Calico (VXLAN) + kube-proxy (nftables) + MetalLB (Layer2) + Traefik.
  k8s stays 1.34.2, patch to 1.34.10. Upgrade to 1.36 = follow-up plan.
- Outage: full window acceptable.

### Phase 2 pre-state (verified 2026-08-14)

- Cilium release is `cilium-1.18.0` (not 1.16.4 as earlier audit believed),
  chart rev 10, deployed 2026-08-05.
- **No kube-proxy DaemonSet exists** — Cilium runs full kube-proxy
  replacement (kubeProxyReplacement=strict). The kubernetes role's DS
  guard (`kubernetes_kube_proxy_ds.rc != 0`) will fire and provision the
  nftables kube-proxy addon during Phase 2 provisioning.
- kube-system has cilium + cilium-envoy DS (4/4 each). No stray kube-proxy
  DS in a cilium namespace anymore (earlier audit record was stale).
- Only IngressClass = `cilium` (cilium.io/ingress-controller). 7 Ingress
  objects reference it — they will be unmanaged during the outage.
- 12 Cilium CRDs present; `kubectl get crd | grep -i cilium | wc -l` = 12.
- `/etc/kubernetes/kubeadm-config.yaml` missing on ansible05 — kubernetes
  role re-renders it before the kube-proxy addon task.
- Node CNI state (ansible05): `/etc/cni/net.d/05-cilium.conflist`,
  `/opt/cni/bin/cilium-cni`. Interfaces: cilium_host/cilium_net,
  lxc_health, lxcebd... nft ruleset contains cilium/KUBE chains (113 hits).
- rp_filter: all=0, default=1 (Calico-compatible).
- k8s.homelab.internal resolves on node via /etc/hosts → 192.168.100.15.
- helm ls -A: argocd, cert-manager, cilium, longhorn (no kube-proxy).
- Cluster v1.34.2 (4 nodes), containerd 2.2.5.

## Locked Decisions
- Calico VXLAN, iptables dp, IPPool 10.244.0.0/16, MTU 1450, natOutgoing
- kube-proxy nftables mode (native Rocky 10; GA 1.33+; ipvs deprecated 1.35)
- MetalLB Layer2, pool 192.168.100.40-.49, Traefik LB pinned .42 (no DNS change)
- Traefik default IngressClass; reuses step-ca certs from Ingress TLS secrets
  (hostname SANs, VIP unchanged -> no reissue)
- Calico = Ansible-managed (roles/kubernetes); MetalLB + Traefik = ArgoCD apps
- Ingress-class flips ONLY after Traefik live (avoids ArgoCD selfHeal black-hole)
- Firewall two-phase: add 4789/udp pre-swap; remove cilium ports post-swap
- NetPol: none in use; Calico keeps full K8s NetPol + projectcalico.org/v3
  (capability note)

## Phase 0 — git prep (no cluster change)
- [x] roles/kubernetes: replace Cilium helm with Calico operator + Installation
- [x] kubernetes_calico_* defaults (version supporting k8s 1.34-1.36)
- [x] kubeadm KubeProxyConfiguration fragment (mode nftables, clusterCIDR 10.244.0.0/16)
- [x] group_vars/all: cilium_version -> calico_version; k8s_version 1.34.10
- [x] group_vars/k8s: metallb_pool; keep ingress_vip 192.168.100.42; firewall vars
- [x] cluster/base/metallb (IPAddressPool .40-.49 + L2Advertisement)
- [x] cluster/base/traefik/values.yaml (LB .42, default class traefik)
- [x] cluster/apps/metallb.yaml (sync-wave 0), cluster/apps/traefik.yaml (sync-wave 1, SSA)
- [x] NO class edits this phase
- [x] ansible_lint + okf.py check
- [x] delete roles/kubernetes/templates/cilium-lb.yaml.j2 (stale, unreferenced)

### Phase 0 implementation notes (2026-08-14)
- kubeadm init switched to config-file: `kubeadm init --config
  /etc/kubernetes/kubeadm-config.yaml` (rendered from
  `kubeadm-config.yaml.j2`, v1beta4). Dropped `--skip-phases addon/kube-proxy`
  so fresh clusters get kube-proxy from kubeadm; existing clusters get it via
  `kubeadm init phase addon kube-proxy --config ...`, guarded by a
  kube-proxy DaemonSet presence check (when cp, rc != 0).
- Firewall vars gated: `k8s_calico_ports: [4789/udp]` (VXLAN) +
  `k8s_cilium_ports` (8472/udp, 4244/tcp, 4245/tcp, 7946/tcp) composed in
  k8s_cp/k8s_workers as `kubeadm_*_ports + k8s_calico_ports +
  (k8s_cilium_ports if k8s_cilium_enabled else []) + ['9100/tcp']`;
  `k8s_cilium_enabled: true` until Cilium removed.
- trusted interface `cilium_host` -> `vxlan.calico` in k8s group_vars.
- ArgoCD server ingress `ingressClassName` cilium -> traefik (early, harmless;
  ArgoCD class flips live in Phase 3 with the rest).
- validated: ansible-lint (production profile), `--syntax-check`,
  template render test, `okf.py check` (0 warnings).

## Phase 1 — pre-swap
- [x] firewall: ADD 4789/udp all nodes (ansible05-08; see note below)
- [x] etcd snapshot -> controller
- [x] helm get values cilium > /root/cilium-values-backup.txt
- [x] audit: no LB svc on loopback NodePort; no other svc in .40-.49

### Phase 1 note (2026-08-14)
- Applied via playbooks/firewall-k8s.yml (firewall role). 4789/udp open +
  vxlan.calico interface assigned to trusted zone on ansible05/06/07/08.
  k8s group resolves to 4 hosts (05 cp, 06-08 workers) — hosts.yml has a
  duplicate k8s_workers definition (nested under k8s.children AND top-level
  all.children with ansible08); consolidate in Phase 4 cleanup.
- lint fix while here: roles/firewall — removed dead `firewalld_zone` default;
  register vars renamed `firewall_fw_*` (no-role-prefix violations).
- etcd snapshot (2026-08-14): host etcdctl absent on ansible05; crictl path
  used — `crictl exec <ctr> etcdctl ... snapshot save /var/lib/etcd/<name>.db`
  (container id via `crictl ps --name etcd --state running -q`), moved to
  /var/backups/etcd/ then fetched to /home/alaureijs/backups/etcd/. SHA256
  verified identical node+controller (cdf8ec43...). NOTE: k8s etcd image
  etcdctl (3.6) has no `snapshot status` subcommand — verify by stat/size.
  Playbook: playbooks/tmp-etcd-snapshot.yml.
- cilium values backup (2026-08-14): controller
  /home/alaureijs/backups/cilium-values-backup.txt (517 lines) + scp to
  ansible05:/root/cilium-values-backup.txt (12340 bytes).
- audit (2026-08-14): only LB svc = kube-system/traefik @ .42 (NodePorts
  32204/31696); MetalLB pool .40-.49 otherwise clear. kube-proxy ALREADY
  kube-system DS 4/4 with configmap mode nftables; stray cilium-ns
  kube-proxy DS 2/2 (ansible07+08, expected to vanish with helm uninstall
  cilium). traefik already in kube-system (deploy 2/2, 11d, outside ArgoCD
  — Phase 3 removes old helm release). All 7 Ingresses use
  ingressClassName cilium.

## Phase 2 — swap (outage)
- [x] helm uninstall cilium
- [x] delete cilium CRDs; confirm cilium IngressClass gone
- [x] nodes: rm /etc/cni/net.d/*cilium*, rm /opt/cni/bin/cilium-cni*; del cilium ifaces;
      check nft chains, rp_filter
- [x] nodes: rm -rf /sys/fs/bpf/cilium (orphaned socket-LB pins survive helm uninstall,
      intercept host ClusterIP at socket layer with stale service map -> kube-dns broken;
      verified fixed 2026-08-14, all 4 nodes REPLY on 10.96.0.10:53, nat-output counters hit)
- [x] kubeadm init phase addon kube-proxy --config (nftables) — CrashLoop until CNI up (expected)
- [x] install Calico; wait calico-node + controllers ready; kubectl wait node Ready
- [x] systemctl restart kubelet all nodes
- [x] verify: kube-proxy/CoreDNS running, cross-node ping, ClusterIP+NodePort DNAT
      (ClusterIP DNS fixed by BPF cleanup above — 10.96.0.10:53 REPLY all nodes)

## Phase 3 — LB + ingress
- [x] sync bootstrap -> MetalLB (wave 0) -> Traefik (wave 1); LB claims .42
- [x] curl -k https://192.168.100.42 OK
- [x] NOW flip classes in git: monitoring x3, observability x2, longhorn, argocd,
      cert-manager issuer
- [x] live apply: helm upgrade argo-cd + longhorn; kubectl apply issuer; sync monitoring+observability
- [x] all 9 Ingresses class traefik; all hostnames 200/302 on .42
- [x] longhorn instance-managers recreated, volumes reattach; ECK healthy;
      prometheus scrapes new pod IPs
- [x] cert check: all Certificate Ready=True, issuer step-ca Ready; no reissue needed

## Phase 4 — verify + cleanup
- [x] firewall: remove 8472/udp, 4244/4245/tcp, 7946/tcp, cilium_host iface
- [x] provision-kubernetes.yml idempotent + --check clean; ansible_lint
- [x] knowledge + log.md + CHANGELOG (Unreleased -> Added); okf.py check + index --write
- [x] mark plan complete; stub follow-up: k8s 1.34->1.36 before 2026-10-27

### Phase 3 notes (2026-08-14)
- Traefik helm release from Phase 0 was removed; ArgoCD-managed traefik app
  took over (kube-system, LB .42, default class traefik). MetalLB sync-wave 0,
  traefik sync-wave 1 via bootstrap.
- 7 Ingress objects flipped cilium -> traefik in git (commits b90b73b, d4c378a)
  + cert-manager ClusterIssuer `step-ca` live-applied (NOT ArgoCD-managed;
  live `kubectl apply cluster/base/cert-manager/issuer.yaml`).
- ArgoCD sync after class flip: application-controller panics in
  `shouldSelfHeal` (automated sync broken) + ArgoCD CLI login hangs. Reliable
  sync = CRD patch:
  `kubectl -n <ns> patch app <name> --type merge -p '{"operation":{"initiatedBy":{"username":"opencode"},"sync":{"revision":"<SHA>","prune":true}}}'`
  (web UI via `kubectl port-forward svc/argocd-server 8090:80`).
- Kibana stuck `WAIT_FOR_YELLOW_SOURCE` on `.kibana_task_manager_9.4.4_001`:
  pod started migration before corrupt index deleted -> stale migration state.
  Fix: scale deploy/observability-kb to 0 -> wait -> 1; fresh boot recreates
  index. (Root cause: migration ran while cert-manager webhook unreachable.)
- Longhorn volume `pvc-f7cd650a` (grafana PV on ansible06) degraded since
  2026-08-04 (PRE-migration): ansible07 disk `default-disk-fc0400000000` has
  DiskPressure (ScheduledTotal 96.6G > ProvisionedLimit 88.98G); 1 replica,
  rebuild blocked by insufficient storage. Not migration-caused. Follow-up.
- ES cluster single-node (`number_of_nodes: 1`): yellow with 2 unassigned
  replicas is expected. observability app shows Progressing (ES yellow) — ok.
- Prometheus 21 targets all `up`; all Certificates Ready=True (no reissue).

### Phase 4 notes (2026-08-14)
- Removed `k8s_cilium_ports` (8472/udp, 4244/tcp, 4245/tcp, 7946/tcp) +
  `k8s_cilium_enabled` from group_vars/k8s/main.yml; firewall_ports composed
  as `kubeadm_*_ports + k8s_calico_ports + ['9100/tcp']` in k8s_cp/k8s_workers.
- FIREWALL ROLE LIMITATION: roles/firewall/tasks/firewalld.yml only ENABLES
  ports/services/interfaces — never disables. Removed ports stay open unless
  manually removed. Cleanup done via ad-hoc `ansible.posix.firewalld`
  (state=disabled, immediate) on all 4 nodes + removed stale `cilium_host`
  trusted-zone interface. Live verified: only Calico/k8s ports remain.
- Duplicate `k8s_workers` group definition in hosts.yml (nested under
  k8s.children + top-level with ansible08) — consolidated in this commit;
  k8s group = ansible05(cp) + 06-08(workers).
- Cilium fully gone: no pods, no helm release, 0 CRDs, no services, only
  `traefik` IngressClass; `cilium_host` iface absent on nodes.
- lint: fixed 5 pre-existing var-naming violations (register: ports/services)
  in roles/firewall molecule verify files -> firewall_*_result. Production
  profile clean.

## Rollback
- etcd snapshot + git revert + helm install cilium (saved values) + re-apply
  cilium-lb.yaml.j2; revert classes; re-sync

## Risks
- kube-proxy ConfigMap clusterCIDR must read 10.244.0.0/16 (SNAT)
- calico felix vs native kube-proxy nftables coexistence (verify P2)
- longhorn/ECK recovery latency post-CNI
- 1.34 EOL clock (upgrade before Oct)
