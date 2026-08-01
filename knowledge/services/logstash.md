---
type: Service
title: Logstash
description: Log ingestion and transformation feeding Elasticsearch on ansible03.
resource: https://observability.homelab.internal/
tags: [elk, logstash, logs]
status: stable
sources:
  - id: es-doc
    resource: ../../docs/elasticsearch.md
    title: ELK stack documentation
    last_modified: 2026-07-31
  - id: elk-config-doc
    resource: ../../docs/elk-configuration.md
    title: ELK configuration manual
    last_modified: 2026-07-31
generated:
  by: human:alaureijs
  at: 2026-08-01T13:30:00Z
verified:
  - by: human:alaureijs
    at: 2026-08-01T13:30:00Z
---

## Runtime

- Own pod via `podman kube play`, **host network mode**; 2g heap.
- Beats input on `:5044`, monitoring API on `:9600`.
- Output to Elasticsearch at `127.0.0.1:9200` (shared host loopback with the
  [/services/elasticsearch.md](/services/elasticsearch.md) pod).
- Config/pipeline split on disk: `/etc/elk/logstash/config/` and
  `/etc/elk/logstash/pipeline/`.
- `logstash-exporter` sidecar on `:9198` for Prometheus (queried by the
  node-exporter textfile collector on elk hosts).

## Pipeline

Grok filters for syslog/nginx patterns; ES output index
`{beat}-{YYYY.MM.dd}`. Custom pipelines can be added by editing
`/etc/elk/logstash/pipeline/` and restarting the container.[^elk-config-doc]

## Management

```bash
podman restart logstash-logstash
curl -s http://127.0.0.1:9600/_node/stats | jq .
```

[^es-doc]: ELK stack documentation — architecture
[^elk-config-doc]: ELK configuration manual — pipelines, inputs, outputs
