# Plan: k8s Cluster (kubeadm) + ArgoCD → Monitoring & Observability

Deploy a kubeadm cluster (3 Rocky 10.2 VMs, Cilium CNI, containerd) with
ArgoCD GitOps deploying `monitoring` (kube-prometheus-stack) and
`observability` (ECK ES/Kibana/Logstash + OpenTelemetry) as Helm apps.
Podman stack roles/docs kept in parallel. Manifests live in repo `cluster/`.

## Decisions

| Decision | Value |
|----------|-------|
| Distribution / topology | kubeadm, Rocky 10.2, 1 control-plane + 3 workers |
| Cluster VMs | New VMs via libvirt role (default pool) |
| CNI | Cilium (kube-proxy replacement, VXLAN overlay) |
| CRI | containerd (`SystemdCgroup=true`) |
| Packaging | Helm charts via ArgoCD (app-of-apps) |
| GitOps repo | Subdir `cluster/` in this repo |
| Secrets | SOPS + age (k8s Secrets committed encrypted) |
| Prereq scope | ansible04 only (Unbound DNS + step-ca ACME) |
| Old stack | Kept in code, parallel (no ansible01/02/03 re-provision) |
| Ingress | ingress-nginx via MetalLB (Layer2 pool .40-.49) |
| Certs | cert-manager ClusterIssuer ACME → step-ca |
| Storage | local-path-provisioner (ES 50 Gi / Prometheus PVCs) |

## VMs

| VM | IP | MAC | Role | Size |
|----|----|-----|------|------|
| ansible05 | 192.168.100.15 | 52:54:00:aa:00:15 | control-plane + ArgoCD + ingress + MetalLB + cert-manager | 2 vCPU / 4 GB / 80 GB |
| ansible06 | 192.168.100.16 | 52:54:00:aa:00:16 | worker — monitoring | 2 vCPU / 6 GB / 80 GB |
| ansible07 | 192.168.100.17 | 52:54:00:aa:00:17 | worker — observability | 2 vCPU / 10 GB / 120 GB |
| ansible08 | 192.168.100.18 | 52:54:00:aa:00:18 | worker | 2 vCPU / 6 GB / 80 GB |

## P1 — Scaffold (repo)

- [x] Write this plan
- [x] `inventory/hosts.yml`: add `k8s` group (`k8s_cp` → ansible05, `k8s_workers` → ansible06/07/08); add ansible05/06/07/08 to `libvirt` group
- [x] `inventory/host_vars/ansible05/main.yml` — vm_name, vm_mac `52:54:00:aa:00:15`, vm_ip `.15`, vm_hostname, vm_vcpus 2, vm_memory 4096, vm_disk 80
- [x] `inventory/host_vars/ansible06/main.yml` — `.16`, 6144 MB, 80 GB
- [x] `inventory/host_vars/ansible07/main.yml` — `.17`, 10240 MB, 120 GB
- [x] `inventory/host_vars/ansible08/main.yml` — `.18`, `52:54:00:aa:00:18`, 6144 MB, 80 GB
- [x] `inventory/group_vars/k8s/main.yml` — `pod_network_cidr: 10.244.0.0/16`, `service_network_cidr: 10.96.0.0/12`, `metallb_pool: 192.168.100.40-192.168.100.49`, VIP constants, kubeadm port list
- [x] `inventory/group_vars/all/main.yml`: version vars — `k8s_version`, `containerd_version`, `cilium_version`, `argocd_version`, `metallb_version`, `ingress_nginx_version`, `cert_manager_version`, `kube_prometheus_stack_version`, `eck_version`, `opentelemetry_operator_version`
- [x] `dns_records` + controller `/etc/hosts`: ansible05/06/07/08.homelab.internal + argocd.homelab.internal; monitoring/observability repointed to VIPs; old ansible01/02/03 + harbor entries removed
- [x] Verify: `ansible-inventory --list`/`--graph` parses clean; `group_vars/k8s` vars inherit on ansible05/06/07/08

## P1b — Decommission ansible01-03 + packages/otel services from inventory

- [x] `inventory/hosts.yml`: delete `harbor`/`monitoring`/`elk`/`packages`/`otel` groups; remove ansible01/02/03 from `libvirt` (leaves ansible04-07)
- [x] Delete `host_vars/ansible01/` (main.yml, provision.yml), `ansible02/`, `ansible03/`
- [x] Delete `group_vars/harbor/` (main.yml, images.yml), `monitoring/`, `elk/`, `packages/`, `otel/`
- [x] `group_vars/all/main.yml`: drop `packages.homelab.internal` from `dns_records`
- [x] `group_vars/portal/main.yml`: remove packages entry from `nginx_directories`, `nginx_vhosts`, and `certificates_extra`
- [x] Delete `playbooks/sync-content.yml` (all 3 plays targeted removed inventory: packages role play, harbor_containers `hosts: ansible01`, documents-copy fed dead reports)
- [x] Keep roles (`harbor*`, `monitoring`, `elasticsearch`, `logstash`, `kibana`, `otel`, `packages`, `node_exporter`, `common`) and provision-ansible01/02/03 playbooks in code as reference (no inventory targets)
- [x] Verify: `ansible-inventory --graph` → pki/portal/k8s(k8s_cp,k8s_workers)/libvirt only; `libvirt` = ansible04-07
- [ ] P10 knowledge: remove packages service + ansible01-03 from network.md/dns.md, services/otel.md, services/packages.md; `log.md` entry

## P2 — ansible04 first: DNS + step-ca (prerequisite for cluster)

- [x] Re-provision ansible04: `playbooks/provision-ansible04.yml` (common+dns+step-ca+nginx) — independent of cluster VMs, run before kubeadm
- [x] Verify: DNS via libvirt dnsmasq (refactored from unbound in ba132d5) at `dig @192.168.100.1 ansible05.homelab.internal` + `argocd.homelab.internal` (VIP) → both resolve; `curl -sk https://ca.homelab.internal:9000/health` → ok; ACME dir `https://pki.homelab.internal/acme/acme/directory` reachable; CA portal 200
- [x] step-ca root CA backed up to controller `files/step-ca/`; VMs trust via certificates role as they come up

## P3 — VM provisioning

- [x] Syntax check `playbooks/libvirt.yml`
- [x] Run `/usr/bin/ansible-playbook playbooks/libvirt.yml` (scoped temp inventory `inventory/tmp-libvirt-cluster.yml`)
- [x] Verify `virsh -c qemu:///system list --all` shows ansible05/06/07/08 running
- [x] Verify `ssh root@192.168.100.15/16/17/18` (cloud-init 2-5 min) — all done
- [x] NOTE: static DHCP host entries missed on 05-08 (dns role ran with ansible04-only inventory); added via `virsh net-update add-last ip-dhcp-host` live+config. Root cause: dns role destroy/recreate + template loop over `groups['libvirt']`. Fixed permanently — dns role now uses surgical net-update (dhcp host / dns host / forwarder diffs), no network bounce; template `<option value=6>` removed (redundant, libvirt auto-injects DNS)

## P4 — Base OS + k8s prereqs

- [x] `playbooks/provision-ansible05.yml` (common + hardening + k8s prereqs)
- [x] `playbooks/provision-ansible06.yml`, `provision-ansible07.yml` (+ `provision-ansible08.yml`)
- [x] host_vars: `hardening_ip_forwarding: true`; sysctls br_netfilter/bridge-nf-call-iptables; hardening modules not blocking kubelet
- [x] firewall: cp 6443/2379-2380/10250/8472(udp), workers 10250/8472(udp)
- [x] Lint playbooks (pipx) → 0; `--check`; run; idempotency re-run

Note: k8s hosts are `ansible05-08`, all provisioned (common + hardening + firewall + certificates + node_exporter). `firewall_ports` wired per group via `group_vars/k8s_cp` (cp: 6443/2379/2380/10250/10257/10259 + 8472/udp + 9100) and `group_vars/k8s_workers` (workers: 10250 + 8472/udp + 30000-32767 + 9100). `br_netfilter` requires `kernel-modules-extra-$(uname -r)` on Rocky 10 cloud images (module not in kernel-modules-core) — hardening sysctl.yml installs it, loads the module, persists via modules-load.d. Idempotency fixes found en route: certs role renewal threshold 30d == step-ca lifetime 30d caused cert churn every run → lowered to 7d; node_exporter version grep matched Go runtime version (`1.26.5`) too → anchored to `version \K` + `head -1`.

## P5 — Cluster bootstrap — role `kubernetes`

- [x] Scaffold `roles/kubernetes/{defaults,tasks,templates,meta}/main.yml`
- [x] containerd (SystemdCgroup=true) + kubelet/kubeadm/kubectl from `pkgs.k8s.io`
- [x] `kubeadm init` on ansible05 (`--pod-network-cidr` + `--skip-phases addon/kube-proxy`)
- [x] Copy `super-admin.conf` (kubeadm 1.34; not `admin.conf`) to controller `~/.kube/config`
- [x] Join token + CA hash; `kubeadm join` ansible06/07/08
- [x] Cilium via Helm (kubeProxyReplacement=true, VXLAN, `k8sServiceHost` for no-kube-proxy)
- [x] k9s TUI: install on controller (k9s.io, pacman `k9s`), runs against `~/.kube/config`; document usage in `docs/k8s.md` (P10)
- [x] Lint role; `playbooks/provision-kubernetes.yml`; `--check`; run
- [x] Verify `kubectl get nodes -o wide` = 3 Ready; kube-system healthy

## P7 — Cluster core + ArgoCD

- [x] `cluster/` tree: `apps/` (Application CRs), `base/<app>/` (Helm values), `.sops.yaml`
- [x] MetalLB (Helm) + Layer2 config, pool `.40-.49`
- [x] ingress-nginx (Helm) LoadBalancer; verify VIP
- [x] cert-manager (Helm) + ClusterIssuer ACME → step-ca
- [x] local-path-provisioner (default StorageClass)
- [x] ArgoCD (Helm): admin password (SOPS), ingress `argocd.homelab.internal`
- [x] Repo: SSH deploy key (SOPS-encrypted) + ArgoCD repo Secret; `argocd repo add` OK
- [x] SOPS: install sops+age; age key encrypted in `cluster/`; SOPS_AGE_KEY to ArgoCD (ksops/plugin)
- [x] Verify ArgoCD UI + repo connection

## P8 — Applications (ArgoCD, Helm)

- [ ] `cluster/apps/bootstrap.yaml` (app-of-apps root)
- [ ] `cluster/apps/monitoring.yaml` → kube-prometheus-stack
  - [ ] `cluster/base/monitoring/values.yaml`: Grafana admin (SOPS), ingress `monitoring.homelab.internal`, node-exporter DaemonSet, kube-state-metrics
  - [ ] Sync; verify Grafana login, Prometheus targets up
- [ ] `cluster/apps/observability.yaml` → ECK + OTel operator
  - [ ] ES CR single-node, heap 4g, 50 Gi PVC (local-path)
  - [ ] Kibana CR + Logstash CR
  - [ ] opentelemetry-operator + Collector DaemonSet (journald + filelog → ES)
  - [ ] ingress `observability.homelab.internal` (`/kibana/`, `/elasticsearch/`)
  - [ ] Sync; verify ES health, Kibana UI, `logs-generic.otel-default` stream

## P9 — DNS + TLS verify

- [ ] Re-run dns role after final `dns_records` update
- [ ] `dig @192.168.100.13` monitoring/observability/argocd → VIPs
- [ ] `curl -vk` each URL; cert-manager certs valid, SAN correct
- [ ] step-ca root CA trusted on all nodes

## P10 — Docs / knowledge / commit

- [ ] `docs/k8s.md`, `docs/argocd.md`
- [ ] knowledge: `infrastructure/k8s.md` (or ansible05/06/07/08), `services/argocd.md`, update monitoring/elasticsearch/logstash/kibana/otel (k8s path parallel), `roles/kubernetes.md`, `playbooks/index.md`
- [ ] `knowledge/log.md` entry
- [ ] `python3 scripts/okf.py check` → 0; `okf.py index --write`
- [ ] CHANGELOG `### Added`
- [ ] Commit via commit-release (push only on request)

## P11 — Optional later

- [ ] Re-provision ansible01 Harbor + sync images (k8s pull-through)
- [ ] `KUBECONFIG` in `opencode.json` → kubernetes-mcp active
- [ ] Migrate VM node_exporter/otel roles off after parallel window

## Run Order

1. P1 scaffold (inventory, group_vars, dns_records)
2. P2 ansible04 (dns+step-ca) — before cluster VMs
3. P3 `playbooks/libvirt.yml`
4. P4 `provision-ansible05/06/07/08.yml`
5. P5 `provision-kubernetes.yml`
6. P7 core via kubectl/helm, ArgoCD bootstrap
7. P8 ArgoCD app-of-apps sync
8. P9 DNS + TLS verify
9. P10 docs/knowledge/commit

## Validation

- `kubectl get nodes -o wide` → 3 Ready
- `kubectl get pods -A` → all Running
- Grafana: `https://monitoring.homelab.internal/grafana/`
- Kibana: `https://observability.homelab.internal/kibana/`
- ES health: `curl -sk https://observability.homelab.internal/elasticsearch/_cluster/health`
- ArgoCD: `https://argocd.homelab.internal/`
- OTel data stream `logs-generic.otel-default` ingesting
- Certs: cert-manager certificates Ready, step-ca CA trusted

## Execution Constraints

- Runs: `/usr/bin/ansible-playbook` (pipx ADT venv lacks libvirt bindings)
- Lint: `export PATH="$HOME/.local/share/pipx/venvs/ansible-dev-tools/bin:$PATH"` then `ansible-lint`
- Every run: lint → `--check` → run → idempotency re-run → knowledge sync
- k8s nodes use containerd (no Podman CRI)
- **k9s** (terminal UI, k9s.io): installed on the controller, uses `~/.kube/config` (copied from ansible05 admin.conf in P5). Primary ops view: `k9s` → nodes/pods; `:ns`, `:pods`, `:deploy`, `:svc` navigation; `shift+f` to follow logs; `d` to describe; `e` to edit. kubeconfig context `kubernetes-admin@kubernetes`.
