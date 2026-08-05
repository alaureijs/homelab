# Plan: Cilium native routing migration (fix MetalLB VIP .42 drops)

## Problem

External traffic to MetalLB VIP 192.168.100.42 is silently dropped by Cilium
when the LB hash picks a backend pod on the same node that received the packet
(ingress node = MetalLB L2 owner = ansible08). Root cause = upstream Cilium bug
#44630 (closed "not planned", no fix): `cil_from_netdev` consumes the SYN in
VXLAN tunnel mode when the backend is local. Conntrack shows BackendID=20
(10.0.0.170, local ingress-nginx pod), zero packets forwarded, no drop/trace
events. ~⅓ of hashes hit the local backend → ~30-65% VIP failure rate.

## Fix

Migrate Cilium from `routingMode: tunnel` (vxlan) to `routingMode: native`
with `autoDirectNodeRoutes: true`. All 4 nodes are on the same L2
(192.168.100.0/24), so no BGP needed — direct node routes suffice. Native mode
does not use the broken `cil_from_netdev` tunnel path for same-node delivery.

## Tasks

- [x] Edit `roles/kubernetes/defaults/main.yml`: `routingMode: native`,
      remove `tunnelProtocol`, add `autoDirectNodeRoutes: true`,
      `ipv4NativeRoutingCIDR: "10.0.0.0/8"`
- [x] Edit `roles/kubernetes/tasks/main.yml`: replace `--set tunnelProtocol`
      with `--set autoDirectNodeRoutes` + `--set ipv4NativeRoutingCIDR`
- [x] Lint (`ansible_lint` role)
- [x] Apply via `helm upgrade --install cilium cilium/cilium` with matching
      values (host has kubeconfig + helm)
- [x] Verify: cilium ds rollout, nodes Ready, cilium status OK
- [x] Verify: node routes exist (`ip route` shows pod CIDRs via node IPs)
- [x] Verify: `.42:443` from host — 0 failures; also `.42:80`
- [x] Verify: ingress-nginx reachable, monitoring/observability healthy
- [x] Re-run playbook dry-run to confirm no drift (`helm get values` matches
      `kubernetes_cilium_values`)
- [ ] Commit, update `knowledge/log.md`, `CHANGELOG.md`, check off P9 in
      `Plans/Plan_k8s.md`

## Firewall regression (native routing exposes node-forwarding)

Native routing makes pods reachable from the node network; firewalld's
`filter_FORWARD_POLICIES` reject dropped cross-node pod traffic. Rich/direct
rules cannot express the forward path (`forward`/`family="ipv4_forward"`
elements invalid; direct rules are `ip`-family only). Fix uses firewalld
**policy objects** (permanent, created before reload):

- `roles/firewall/defaults/main.yml`: `firewall_trusted_sources`,
  `firewall_trusted_interfaces`, `firewall_forward_policies`
- `roles/firewall/tasks/firewalld.yml`: trusted source/interface tasks +
  idempotent policy shell task (`--query-ingress-zone`/`--query-egress-zone`
  guard; create-detection via `--new-policy` rc/success; target+priority set)
- `inventory/group_vars/k8s/main.yml`: `pod_network_cidr: 10.0.0.0/8`,
  trusted source `10.0.0.0/8`, interface `cilium_host`, policy `allow-pod-fwd`
  (ingress `public` → egress `trusted`, ACCEPT, priority 50)
- Applied live to ansible05/06/07/08; `playbooks/firewall-k8s.yml` real run
  idempotent (first run changed only ansible05; second run `changed=0`)
- Verified: host → VIP `.42:443/.42:80` 30/30; argocd/longhorn 200 via VIP;
  cross-node pod `10.0.0.170 → 10.0.1.77` 404 (ingress-nginx); node ping to
  remote pod OK; NodePort path OK; temp nft trace table removed

## Rollback

`helm upgrade cilium cilium/cilium --reuse-values` with tunnel values restored
in defaults; verify tunnel mode recovers.
