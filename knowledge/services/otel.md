---
type: Service
title: OpenTelemetry log collection
description: otel-collector agents on all VMs shipping journald and file logs over mTLS to ELK.
resource: roles/otel/
tags: [otel, logging, elk, observability]
status: stable
sources:
  - id: es-doc
    resource: ../../docs/elasticsearch.md
    title: ELK stack documentation (OpenTelemetry logs section)
    last_modified: 2026-07-31
generated:
  by: human:alaureijs
  at: 2026-08-01T13:30:00Z
verified:
  - by: human:alaureijs
    at: 2026-08-01T13:30:00Z
---

## Runtime

- `otelcol-contrib` v0.157.0 on all four VMs (binary synced via the internal
  packages server), deployed by `playbooks/provision-otel.yml`.
- Pipeline: journald + filelog receivers → resourcedetection/system + batch
  (5s/512) → elasticsearch exporter with `mapping.mode: otel`.[^es-doc]

## Transport

- **Endpoint**: `https://observability.homelab.internal/elasticsearch`
  (nginx on ansible03 → `127.0.0.1:9200`).
- **Auth**: mTLS — per-host step-ca client certs in `/etc/otel-client/`
  (`otel-client.crt`, `otel-client.key`, combined CA). No client cert → HTTP 400.

## File paths

Per host via `otel_log_paths`: `/var/log/harbor/*.log`, `/var/log/nginx/*.log`,
`/var/log/elk/*.log`.

## Data lifecycle

- Data stream `logs-generic.otel-default`; ILM `otel-logs-policy`
  (rollover 1d/50 GB, delete after 30d).
- After any certificate renewal, re-run `provision-otel.yml` to restore
  `0644` on the client key — the certificates role resets it to `0600`,
  which blocks the collector from starting.

[^es-doc]: ELK stack documentation — OTel pipeline, mTLS, ILM, certificate renewal note
