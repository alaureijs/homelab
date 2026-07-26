# ELK Stack Documentation

## Overview

Elasticsearch/Logstash/Kibana stack deployed on `ansible03` (192.168.100.12) for centralized log management. Each component runs as an independent pod via `podman kube play`.

## Architecture

```
Client (Filebeat) → Logstash (5044) → Elasticsearch (9200)
                                          ↓
Kibana (5601) ← nginx (443) → Elasticsearch (9200)
```

- **Elasticsearch**: Single-node, security disabled, 4g heap, data in `/var/lib/elk/elasticsearch/` (own pod)
- **Logstash**: Beats input (5044), grok filters for syslog/nginx, ES output, 2g heap (own pod)
- **Kibana**: HTTP UI on 5601, connected to Elasticsearch (own pod + nginx reverse proxy)
- **Elasticsearch Exporter**: Sidecar in Elasticsearch pod on port 9114
- **Nginx**: HTTPS reverse proxy on 443, routes `/kibana/` and `/elasticsearch/`

## Access URLs

- Kibana: `https://observability.homelab.internal/kibana/`
- Elasticsearch: `https://observability.homelab.internal/elasticsearch/`

## Usage

### Send Logs to ELK Stack

Install Filebeat on clients and configure it to send logs to Logstash:

```yaml
# /etc/filebeat/filebeat.yml
output.logstash:
  hosts: ["192.168.100.12:5044"]

filebeat.inputs:
  - type: log
    paths:
      - /var/log/*.log
    fields:
      type: syslog
```

### Index Patterns

Logstash creates indices in the format: `{beat}-{YYYY.MM.dd}`

- `filebeat-{YYYY.MM.dd}` - Filebeat logs
- `system-{YYYY.MM.dd}` - System logs

### Kibana Usage

1. Open `https://observability.homelab.internal/kibana/`
2. Go to **Management → Stack Management → Index Patterns**
3. Create index pattern: `filebeat-*` or `system-*`
4. Go to **Discover** to view logs

## Container Configuration

- **Podman CNI network**: `elk` (shared across all three pods)
- **Inter-service communication**: All pods use `hostIP: 127.0.0.1` + `hostPort`. Logstash/Kibana connect to Elasticsearch via `127.0.0.1:9200`.
- **Volume mounts**: Separate host directories for configs (Logstash config/pipeline split)
- **Image pulls**: Auth via Harbor credentials, TLS trust via CA cert
- **Deploy fix**: `chown -R 1000:1000` on Elasticsearch data dir after `kube play`

## Troubleshooting

### Elasticsearch Permission Denied

Elasticsearch runs as uid 1000. After `kube play`, the data directory may be owned by root:

```bash
chown -R 1000:1000 /var/lib/elk/elasticsearch/
podman restart elasticsearch-elasticsearch
```

### Kibana Fails to Start

Kibana 8.x doesn't accept `xpack.security.enabled` in `kibana.yml`. Use the `XPACK_SECURITY_ENABLED` environment variable instead.

### Podman kube play Authentication

`podman kube play` doesn't support `--authfile`. Write auth to `/root/.config/containers/auth.json`:

```bash
podman login harbor.homelab.internal --authfile /root/.config/containers/auth.json
```

## Logs

Container logs are managed via rsyslog (journald → `/var/log/elk/`). To view ELK-specific logs:

```bash
ssh root@192.168.100.12
podman logs elasticsearch-elasticsearch
podman logs logstash-logstash
podman logs kibana-kibana
```

## Management Commands

```bash
# Deploy/redeploy ELK stack
ansible-playbook playbooks/provision-ansible03.yml

# Deploy individual components
ansible-playbook playbooks/provision-ansible03.yml --limit ansible03 -e "elk_component=elasticsearch"

# Restart individual containers
podman restart elasticsearch-elasticsearch
podman restart logstash-logstash
podman restart kibana-kibana

# Check Elasticsearch cluster health
curl -s http://192.168.100.12:9200/_cluster/health?pretty

# Check Kibana status
curl -s http://192.168.100.12:5601/api/status | python3 -c 'import sys,json; print(json.load(sys.stdin)["status"]["overall"]["level"])'

# Check Elasticsearch exporter metrics
curl -s http://192.168.100.12:9114/metrics | head -5
```
