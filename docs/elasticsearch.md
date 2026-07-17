# ELK Stack Documentation

## Overview

Elasticsearch/Logstash/Kibana stack deployed on `ansible03` (192.168.100.12) for centralized log management.

## Architecture

```
Client (Filebeat) → Logstash (5044) → Elasticsearch (9200)
                                          ↓
Kibana (5601) ← nginx (443) → Elasticsearch (9200)
```

- **Elasticsearch**: Single-node, security disabled, 4g heap, data in `/var/lib/elk/elasticsearch/`
- **Logstash**: Beats input (5044), grok filters for syslog/nginx, ES output, 2g heap
- **Kibana**: HTTP UI on 5601, connected to Elasticsearch
- **Nginx**: HTTPS reverse proxy on 443, routes `/kibana/` and `/elasticsearch/`

## Access URLs

- Kibana: `https://observability.local.lan/kibana/`
- Elasticsearch: `https://observability.local.lan/elasticsearch/`

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

1. Open `https://observability.local.lan/kibana/`
2. Go to **Management → Stack Management → Index Patterns**
3. Create index pattern: `filebeat-*` or `system-*`
4. Go to **Discover** to view logs

## Container Configuration

- **Podman CNI network**: `elk`
- **Volume mounts**: Separate host directories for configs (Logstash config/pipeline split)
- **Image pulls**: Auth via Harbor credentials, TLS trust via CA cert
- **Deploy fix**: `chown -R 1000:1000` on Elasticsearch data dir after `kube play`

## Troubleshooting

### Elasticsearch Permission Denied

Elasticsearch runs as uid 1000. After `kube play`, the data directory may be owned by root:

```bash
chown -R 1000:1000 /var/lib/elasticsearch/
podman restart elk-elasticsearch
```

### Kibana Fails to Start

Kibana 8.x doesn't accept `xpack.security.enabled` in `kibana.yml`. Use the `XPACK_SECURITY_ENABLED` environment variable instead.

### Podman kube play Authentication

`podman kube play` doesn't support `--authfile`. Write auth to `/root/.config/containers/auth.json`:

```bash
podman login harbor.local.lan --authfile /root/.config/containers/auth.json
```

## Logs

Container logs are managed via rsyslog (journald → `/var/log/harbor/`). To view ELK-specific logs:

```bash
ssh root@192.168.100.12
podman logs elk-elasticsearch
podman logs elk-logstash
podman logs elk-kibana
```

## Management Commands

```bash
# Deploy/redeploy ELK stack
ansible-playbook playbooks/provision-ansible03.yml

# Restart ELK containers
ansible-playbook playbooks/provision-ansible03.yml --tags restart-elk

# Check Elasticsearch cluster health
curl -s https://observability.local.lan/elasticsearch/_cluster/health | jq .

# Check Kibana status
curl -s https://observability.local.lan/kibana/api/status | jq .
```
