# Plan: k8s Follow-up Items (post-Calico migration)

- Status: Open
- Date: 2026-08-14
- Scope: Open items raised during/after the Cilium→Calico migration
  (`Plans/Plan_CalicoMigration.md`, all phases complete). No outage needed.

## Items

- [ ] k8s 1.34 → 1.36 upgrade before 2026-10-27 (1.34 EOL clock; kubeadm
      minor-bump both control-plane and workers, verify kube-proxy nftables
      still GA on 1.36, Calico operator version supports 1.36)
- [ ] Longhorn volume `pvc-f7cd650a` (grafana PV on ansible06) — degraded
      since 2026-08-04 (pre-migration). Only 1 replica running; 2nd replica
      rebuild blocked by `ReplicaSchedulingFailure` — ansible07 disk
      `default-disk-fc0400000000` has DiskPressure (ScheduledTotal 96.6G >
      ProvisionedLimit 88.98G). Options: expand ProvisionedLimit on ansible07
      disk, move grafana replica to ansible08 (schedulable), or reduce
      grafana PV size. Verify volume back to healthy after fix.
- [ ] `roles/firewall` only enables firewalld ports/services/interfaces —
      never disables removed ones. Consider adding an explicit "denylist"
      or documenting manual removal as the standard teardown path.
- [ ] ArgoCD application-controller panics in `shouldSelfHeal` — automated
      sync broken; syncs done via CRD operation patch (web UI
      port-forward svc/argocd-server 8090:80). Investigate/upgrade ArgoCD
      to restore self-heal.
- [ ] ArgoCD CLI login hangs — web UI works; document working auth flow or
      fix CLI (likely cert/redirect issue with the traefik ingress).
- [ ] `observability` ArgoCD app shows Progressing while ES is yellow
      (single-node, 2 unassigned replicas — expected). Consider a health
      check/liveness that tolerates single-node yellow so the app reports
      Healthy.
