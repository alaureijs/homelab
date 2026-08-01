# ELK Stack Documentation

## Overview

Elasticsearch/Logstash/Kibana stack deployed on `ansible03` (192.168.100.12) for centralized log management. Each component runs as an independent pod via `podman kube play`.

## Architecture

```
Client (otel-collector) → nginx /elasticsearch/ → Elasticsearch (9200)
                                                      ↓
Kibana (5601) ← nginx (443) → Elasticsearch (9200)
                                                      ↑
otel-collector (all VMs, journald+files, mTLS) → nginx /elasticsearch/
```

- **Elasticsearch**: Single-node, security disabled, 2g heap, data in `/var/lib/elk/elasticsearch/` (own pod)
- **Logstash**: Beats input (5044), grok filters for syslog/nginx, ES output, 2g heap (own pod)
- **Kibana**: HTTP UI on 5601, connected to Elasticsearch (own pod + nginx reverse proxy)
- **Elasticsearch Exporter**: Sidecar in Elasticsearch pod on port 9114
- **Nginx**: HTTPS reverse proxy on 443, routes `/kibana/` and `/elasticsearch/`
- **OpenTelemetry**: `otel-collector` on all VMs ships journald + file logs
  over mTLS to the `/elasticsearch/` endpoint (see below)

## Access URLs

- Kibana: `https://observability.homelab.internal/kibana/`
- Elasticsearch: `https://observability.homelab.internal/elasticsearch/`

## Usage

### Kibana Usage

1. Open `https://observability.homelab.internal/kibana/`
2. Go to **Management → Stack Management → Index Patterns**
3. Create index pattern: `logs-generic.otel-default` (OTel logs)
4. Go to **Discover** to view logs

## OpenTelemetry Logs

`otel-collector` (otelcol-contrib v0.157.0) runs on all 4 VMs (`roles/otel/`,
`playbooks/provision-otel.yml`) and ships journald + file logs to
Elasticsearch via the nginx reverse proxy:

- **Endpoint**: `https://observability.homelab.internal/elasticsearch`
  (nginx on ansible03 → `127.0.0.1:9200`)
- **Auth**: mTLS — per-host step-ca client certs in `/etc/otel-client/`
  (`otel-client.crt`, `otel-client.key`, combined CA `mtls-ca-combined.crt`).
  Requests without a client cert get HTTP 400.
- **Pipeline**: journald + filelog receivers → resourcedetection/system +
  batch (5s/512) → elasticsearch exporter (`mapping.mode: otel`)
- **File paths**: per host via `otel_log_paths` (`/var/log/harbor/*.log`,
  `/var/log/nginx/*.log`, `/var/log/elk/*.log`)
- **Data stream**: `logs-generic.otel-default` (backing indices
  `.ds-logs-generic.otel-default-*`)
- **Lifecycle**: ILM policy `otel-logs-policy` — hot phase rollover after
  1 day or 50 GB; delete after 30 days (`elasticsearch_otel_retention`).
  Applied via component template `logs@custom` (`index.lifecycle.name`).

```bash
# Verify OTel data is flowing
curl -s "http://127.0.0.1:9200/_cat/indices/logs-generic*?h=index,docs.count&s=index"

# Check ILM policy
curl -s "http://127.0.0.1:9200/_ilm/policy/otel-logs-policy" | python3 -m json.tool

# mTLS negative test (expect 400 without a client cert)
curl -sk -o /dev/null -w "%{http_code}\n" https://observability.homelab.internal/elasticsearch/
```

After any certificate renewal run (`provision-common.yml`), re-run
`provision-otel.yml` to restore `0644` key permissions — the certificates
role resets the client key to `0600`, which blocks the collector from
starting.

## Container Configuration

- **Networking**: All three ELK pods use host network mode (`podman kube play --network host`). No `hostIP`/`hostPort` mappings — containers bind directly to host ports.
- **Inter-service communication**: Logstash/Kibana connect to Elasticsearch via `127.0.0.1:9200` on the host loopback (shared network namespace).
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
