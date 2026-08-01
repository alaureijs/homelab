---
name: version-bump
description: Bump a component version per LIFECYCLE.md - edit group_vars/all/main.yml, sync to Harbor, re-provision affected host, update CHANGELOG and knowledge
metadata:
  workflow: versioning
---

# version-bump

## What I do
- Bump versions of container images, Harbor, binaries (node_exporter, otel),
  and base images following LIFECYCLE.md.
- Single source of truth: `inventory/group_vars/all/main.yml`.

## When to use me
Use when asked to update/upgrade any component version in the homelab.

## Version variables
| Component | Variable |
|-----------|----------|
| Harbor | `harbor_version` |
| Grafana | `grafana_version` |
| Prometheus / Alertmanager | `prometheus_version` / `alertmanager_version` |
| Node Exporter | `node_exporter_version` |
| Elasticsearch / Logstash / Kibana | `elasticsearch_version` / `logstash_version` / `kibana_version` |
| ES Exporter | `elasticsearch_exporter_version` |
| OTel Collector | `otel_collector_version` |
| step-ca / step-cli | `step_ca_version` / `step_cli_version` |
| Base images (alpine, nginx, ...) | `alpine_version`, `nginx_version`, ... |

## Steps
1. Read `LIFECYCLE.md` section for the component.
2. Edit version in `inventory/group_vars/all/main.yml` only.
3. Verify upstream tag exists (`podman pull ... --dry-run` or registry check).
4. Sync images/binaries: `playbooks/sync-content.yml` (--check first).
5. Re-provision affected host (see ansible-provision skill).
6. Verify: podman ps, health endpoints, Prometheus targets.
7. Update `CHANGELOG.md` and `knowledge/` (version-bump also bumps knowledge).

## Rollback
Revert main.yml (`git checkout HEAD~1 -- inventory/group_vars/all/main.yml`)
and re-provision - old images stay in Harbor, never deleted automatically.
