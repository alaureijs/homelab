# Monitoring Stack

Monitoring stack on ansible02 (192.168.100.11), accessed via `monitoring.local.lan`.

## Architecture

- Deployed via `podman kube play` with K8s YAML manifest
- Podman CNI network (`monitoring`) for container networking
- nginx reverse proxy on port 443 (HTTPS) with TLS
- Prometheus scrapes node-exporter via FQDN with mTLS

## Services

| Service | Image (from Harbor) | Port |
|---------|---------------------|------|
| Grafana | library/grafana/grafana | 3000 |
| Prometheus | prometheus/prometheus/prometheus | 9090 |
| Alertmanager | prometheus/prometheus/alertmanager | 9093 |
| Node Exporter | prometheus/prometheus/node-exporter | 9100 |

All ports bound to `127.0.0.1` via `hostPort` for nginx access only.

## Access

```bash
# Grafana
https://monitoring.local.lan/grafana/
# admin / \$GRAFANA_PASSWORD

# Prometheus
https://monitoring.local.lan/prometheus/
```

## mTLS

Node-exporter scraping uses mutual TLS:

- **CA**: `/etc/prometheus/mtls/ca.crt` (on both hosts)
- **Server cert**: `/etc/pki/tls/certs/node-exporter.crt` (per host)
- **Client cert/key**: `/etc/prometheus/mtls/client.{crt,key}` (Prometheus)

Prometheus scrapes:
- `ansible01.local.lan:9100` (Harbor host)
- `ansible02.local.lan:9100` (monitoring host)

## Certificate Renewal

Auto-renewed within 30 days. CA renewal cascades to server/client certs.

```bash
# Force renewal
ansible-playbook playbooks/provision-ansible02.yml -e monitoring_cert_force_renewal=true

# Check expiry
openssl x509 -in /etc/prometheus/mtls/ca.crt -noout -enddate
openssl x509 -in /etc/prometheus/mtls/client.crt -noout -enddate
```

## SELinux Booleans

| Boolean | State | Purpose |
|---------|-------|---------|
| `httpd_can_network_connect` | on | nginx can connect to pod ports |
| `httpd_can_network_relay` | on | nginx relay capability |

## Management

```bash
# SSH
ssh root@192.168.100.11

# Check containers
podman ps

# Restart monitoring stack
podman kube play --down /opt/monitoring/monitoring-pod.yml && \
podman kube play /opt/monitoring/monitoring-pod.yml

# View Prometheus targets
curl -sk https://monitoring.local.lan/prometheus/api/v1/targets | \
  python3 -c "import sys,json; [print(f\"{t['labels'].get('job','?')}: {t['health']}\") for t in json.load(sys.stdin)['data']['activeTargets']]"
```

## Troubleshooting

### Cockpit conflict

Cockpit uses port 9090, conflicting with Prometheus. It's auto-disabled
by the monitoring role:

```bash
systemctl disable --now cockpit.socket cockpit.service
```

### nginx showing default page

Browser DNS-over-HTTPS bypasses `/etc/hosts`. Disable DoH:
- Firefox: `about:preferences#general` → DNS over HTTPS
- Chrome: `chrome://settings/security` → Use secure DNS
- Floorp: `about:config` → `network.trr.mode` → `0`

### Node Exporter not scraping

```bash
# Verify listening on host IP
ss -tlnp | grep 9100

# Test mTLS from monitoring host
curl -s --cacert /etc/pki/tls/certs/monitoring-ca.crt \
  --cert /etc/prometheus/mtls/client.crt \
  --key /etc/prometheus/mtls/client.key \
  https://ansible01.local.lan:9100/metrics | head -2
```
