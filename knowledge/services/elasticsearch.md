---
type: Service
title: Elasticsearch
description: Single-node Elasticsearch serving the ELK stack and OTel log data stream on ansible03.
resource: https://observability.homelab.internal/elasticsearch/
tags: [elk, elasticsearch, logs]
status: stable
sources:
  - id: es-doc
    resource: ../../docs/elasticsearch.md
    title: ELK stack documentation
    last_modified: 2026-07-31
generated:
  by: human:alaureijs
  at: 2026-08-01T13:30:00Z
verified:
  - by: human:alaureijs
    at: 2026-08-01T13:30:00Z
---

## Runtime

- Own pod via `podman kube play`, **host network mode** (no hostPort
  mappings — binds 9200/9300 directly; do not restart with a CNI network or
  bindings are lost).[^es-doc]
- Single node, security disabled, 2g heap (`-Xmx2g` + 2 GB direct memory to
  avoid OOM on the 8 GB VM).
- Data in `/var/lib/elk/elasticsearch/` (PV/PVC). Runs as uid 1000;
  after `kube play` re-run `chown -R 1000:1000` if root-owned.
- Elasticsearch exporter sidecar on `:9114`, scraped by
  [/services/monitoring.md](/services/monitoring.md).

## Data streams

- **OTel logs** → `logs-generic.otel-default` (backing indices
  `.ds-logs-generic.otel-default-*`), written by the
  [/services/otel.md](/services/otel.md) collectors.
- **Logstash indices** → `{beat}-{YYYY.MM.dd}`.
- ILM policy `otel-logs-policy`: hot rollover after 1 day or 50 GB; delete
  after `elasticsearch_otel_retention` (default 30d), applied via component
  template `logs@custom`.

## Management

```bash
ssh root@192.168.100.12
podman logs elasticsearch-elasticsearch
curl -s http://127.0.0.1:9200/_cluster/health?pretty
curl -s http://127.0.0.1:9200/_cat/indices/logs-generic*?h=index,docs.count&s=index
```

[^es-doc]: ELK stack documentation — architecture, data streams, ILM, troubleshooting
