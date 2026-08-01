---
type: Guide
title: Container deployment patterns
description: How services are deployed with podman kube play and podman-compose in this lab.
tags: [podman, containers, kubernetes]
status: stable
sources:
  - id: container-doc
    resource: ../../docs/container-deployment.md
    title: Container deployment patterns
    last_modified: 2026-07-31
generated:
  by: human:alaureijs
  at: 2026-08-01T14:30:00Z
verified:
  - by: human:alaureijs
    at: 2026-08-01T14:30:00Z
---

## podman kube play

Monitoring and ELK stacks deploy via K8s YAML manifests
(`podman kube play --down` then `--network <name>`).[^container-doc]

- **Volumes**: PV/PVC with `ReadWriteOnce`, reclaim `Retain` (hostPath
  backed) — not bare hostPath mounts.
- **Config**: inline ConfigMaps, not config dir mounts.
- **Ports**: monitoring uses `hostIP: 127.0.0.1` + `hostPort`; ELK pods use
  **host network mode** and must never be restarted with a CNI network
  (host bindings are lost).
- **Ownership fix after play**: grafana=472, prometheus/alertmanager=65534,
  elasticsearch=1000 (`chown -R UID:GID /data/path`).

## Harbor — podman-compose

Harbor uses the offline installer + `prepare` workflow, NOT `kube play`:
extract installer, load images, configure `harbor.yml`, patch compose
(rewrite `goharbor/*` images to Harbor copies, drop the Docker-only syslog
driver), `prepare --with-trivy`, `podman-compose up -d`.[^container-doc]

## nginx reverse proxy

Ansible02/03 nginx proxies services on 443 at sub-paths
(`/grafana/`, `/prometheus/`, `/kibana/`, `/elasticsearch/`); backend binds
to `127.0.0.1`.

## Troubleshooting

- `podman kube play` fails → check `/root/.config/containers/auth.json`.
- Cert errors → check SANs and expiry.
- Permission errors → re-run the ownership fix.

[^container-doc]: Container deployment patterns — kube play reference, Harbor workflow, troubleshooting
