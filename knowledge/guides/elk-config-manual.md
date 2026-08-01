---
type: Guide
title: ELK configuration manual
description: Variable-driven configuration of the ELK stack without editing role files.
tags: [elk, configuration, kibana, logstash, elasticsearch]
status: stable
sources:
  - id: elk-config-doc
    resource: ../../docs/elk-configuration.md
    title: ELK configuration manual
    last_modified: 2026-07-31
generated:
  by: human:alaureijs
  at: 2026-08-01T14:30:00Z
verified:
  - by: human:alaureijs
    at: 2026-08-01T14:30:00Z
---

## Key variables

Override in `inventory/group_vars/elk/main.yml` or `host_vars/ansible03/`:

| Variable | Default | Description |
|----------|---------|-------------|
| `elasticsearch_heap_size` | `4g` (2g effective) | ES JVM heap |
| `logstash_heap_size` | `2g` | Logstash heap |
| `kibana_port` | `5601` | Kibana port |
| `elk_hostname` | `observability.homelab.internal` | proxy hostname |
| `elk_data_dir` | `/var/lib/elk` | data directory |

## Customizing

- **Elasticsearch**: override vars per host, re-run
  `playbooks/provision-ansible03.yml`.[^elk-config-doc]
- **Logstash pipeline**: edit `/etc/elk/logstash/pipeline/` on the host,
  `podman restart logstash-logstash`.
- **Kibana config**: `/etc/elk/kibana/kibana.yml` on the host,
  `podman restart kibana-kibana`.

## Networking

ELK pods run in **host network mode**; inter-service calls use
`127.0.0.1:9200`. Never restart pods with a CNI network — bindings are lost.

## Restart

```bash
podman kube play --down /etc/elk/elasticsearch-pod.yml
podman kube play --network host /etc/elk/elasticsearch-pod.yml
chown -R 1000:1000 /var/lib/elk/elasticsearch
podman restart elk-elasticsearch
```

[^elk-config-doc]: ELK configuration manual — full variable reference and how-to
