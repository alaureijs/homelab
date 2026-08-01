---
type: Service
title: Kibana
description: Log exploration UI on ansible03, exposed through nginx reverse proxy.
resource: https://observability.homelab.internal/kibana/
tags: [elk, kibana, logs]
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

- Own pod via `podman kube play`, **host network mode**; HTTP on `:5601`.
- Connects to Elasticsearch at `127.0.0.1:9200`.
- nginx reverse proxy serves `/kibana/` over HTTPS; `/elasticsearch/` is
  proxied to `127.0.0.1:9200` and gated by **optional mTLS**
  (`ssl_verify_client optional`, `$ssl_client_verify != SUCCESS → 400`).
- Kibana 8.x: `xpack.security.enabled` goes in the `XPACK_SECURITY_ENABLED`
  environment variable, not `kibana.yml`.[^es-doc]

## Usage

Create index pattern `logs-generic.otel-default` for OTel logs, then browse
in Discover.

## Management

```bash
curl -s http://192.168.100.12:5601/api/status | python3 -c \
  'import sys,json; print(json.load(sys.stdin)["status"]["overall"]["level"])'
```

[^es-doc]: ELK stack documentation — Kibana usage, status check, mTLS endpoint
[^elk-config-doc]: ELK configuration manual — Kibana configuration
