# Monitoring Stack Configuration Manual

This guide explains how to configure the monitoring stack without modifying the role files.

## Overview

The monitoring role uses variables defined in `inventory/group_vars/monitoring/main.yml` and `roles/monitoring/defaults/main.yml`. All configuration is done through these variables or by editing files on the host.

## Configuration Variables

### Grafana

| Variable | Default | Description |
|----------|---------|-------------|
| `monitoring_grafana_admin_password` | `admin` | Admin password |

### Prometheus

| Variable | Default | Description |
|----------|---------|-------------|
| `monitoring_prometheus_retention` | `30d` | Data retention period |
| `monitoring_prometheus_retention_size` | `2GB` | Max storage size |
| `monitoring_prometheus_scrape_interval` | `15s` | Scrape interval |
| `monitoring_prometheus_evaluation_interval` | `15s` | Rule evaluation interval |

### Alertmanager

| Variable | Default | Description |
|----------|---------|-------------|
| `monitoring_alertmanager_smtp_smarthost` | `""` | SMTP server (host:port) |
| `monitoring_alertmanager_smtp_from` | `""` | Sender email address |
| `monitoring_alertmanager_smtp_auth_username` | `""` | SMTP username |
| `monitoring_alertmanager_smtp_auth_password` | `""` | SMTP password |

### General

| Variable | Default | Description |
|----------|---------|-------------|
| `monitoring_hostname` | `monitoring.local.lan` | Reverse proxy hostname |
| `monitoring_config_dir` | `/etc/monitoring` | Configuration directory |
| `monitoring_data_dir` | `/var/lib/monitoring` | Data directory |
| `monitoring_network_name` | `monitoring` | Podman network name |

## How to Configure

### Step 1: Edit Group Variables

Edit `inventory/group_vars/monitoring/main.yml`:

```yaml
---
# Monitoring stack group variables

# Grafana
monitoring_grafana_admin_password: "my-secure-password"

# Prometheus
monitoring_prometheus_retention: "90d"  # Keep data for 90 days
monitoring_prometheus_retention_size: "10GB"
monitoring_prometheus_scrape_interval: "30s"

# Alertmanager (optional SMTP)
monitoring_alertmanager_smtp_smarthost: "smtp.example.com:587"
monitoring_alertmanager_smtp_from: "alerts@example.com"
monitoring_alertmanager_smtp_auth_username: "alerts@example.com"
monitoring_alertmanager_smtp_auth_password: "my-smtp-password"
```

### Step 2: Run Provisioning

```bash
ansible-playbook playbooks/provision-ansible02.yml
```

## Customizing Configurations

### Change Grafana Password

1. Edit `inventory/group_vars/monitoring/main.yml`:

```yaml
monitoring_grafana_admin_password: "new-secure-password"
```

2. Re-run provisioning.

### Add Grafana Dashboards

1. Export dashboard JSON from Grafana UI (Share → Export)
2. Place JSON file in `roles/monitoring/files/dashboards/`
3. Edit `roles/monitoring/defaults/main.yml`:

```yaml
monitoring_grafana_dashboards:
  - name: node-exporter
    file: "{{ role_path }}/files/dashboards/node-exporter.json"
  - name: prometheus
    file: "{{ role_path }}/files/prometheus.json"
  - name: my-new-dashboard
    file: "{{ role_path }}/files/dashboards/my-new-dashboard.json"
```

4. Re-run provisioning.

### Add Prometheus Scrape Targets

1. SSH to ansible02:

```bash
ssh root@192.168.100.11
```

2. Edit the Prometheus config:

```bash
vi /tmp/monitoring-prometheus.yml
```

3. Add new scrape job:

```yaml
scrape_configs:
  - job_name: prometheus
    metrics_path: /prometheus/metrics
    static_configs:
      - targets:
          - localhost:9090

  - job_name: node-exporter
    scheme: https
    tls_config:
      ca_file: /etc/prometheus/mtls/ca.crt
      cert_file: /etc/prometheus/mtls/client.crt
      key_file: /etc/prometheus/mtls/client.key
    static_configs:
      - targets:
          - ansible01.local.lan:9100
          - ansible02.local.lan:9100
        labels:
          cluster: local

  # Add new job
  - job_name: custom-app
    static_configs:
      - targets:
          - app1.local.lan:8080
          - app2.local.lan:8080
```

4. Apply config:

```bash
podman cp /tmp/monitoring-prometheus.yml monitoring-prometheus:/etc/prometheus/prometheus.yml
podman exec monitoring-prometheus kill -HUP 1
```

### Add Alert Rules

1. SSH to ansible02:

```bash
ssh root@192.168.100.11
```

2. Edit the rules file:

```bash
vi /tmp/monitoring-rules.yml
```

3. Add new rules:

```yaml
groups:
  - name: node-exporter
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          description: "CPU usage is above 80% for more than 5 minutes"

  # Add new rule group
  - name: custom-app
    rules:
      - alert: AppDown
        expr: up{job="custom-app"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "App {{ $labels.instance }} is down"
          description: "Application has been unreachable for more than 1 minute"
```

4. Apply rules:

```bash
podman cp /tmp/monitoring-rules.yml monitoring-prometheus:/etc/prometheus/rules/rules.yml
podman exec monitoring-prometheus kill -HUP 1
```

### Configure Alertmanager SMTP

1. Edit `inventory/group_vars/monitoring/main.yml`:

```yaml
monitoring_alertmanager_smtp_smarthost: "smtp.gmail.com:587"
monitoring_alertmanager_smtp_from: "alerts@gmail.com"
monitoring_alertmanager_smtp_auth_username: "alerts@gmail.com"
monitoring_alertmanager_smtp_auth_password: "app-password"
```

2. Re-run provisioning.

### Add Alertmanager Receivers

1. SSH to ansible02:

```bash
ssh root@192.168.100.11
```

2. Edit the Alertmanager config:

```bash
vi /tmp/monitoring-alertmanager.yml
```

3. Add receivers:

```yaml
global:
  smtp_smarthost: "smtp.gmail.com:587"
  smtp_from: "alerts@gmail.com"
  smtp_auth_username: "alerts@gmail.com"
  smtp_auth_password: "app-password"

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: default

receivers:
  - name: default
    email_configs:
      - to: "admin@example.com"
        send_resolved: true

  # Add new receiver
  - name: slack
    slack_configs:
      - api_url: "https://hooks.slack.com/services/xxx/yyy/zzz"
        channel: "#alerts"
        send_resolved: true

inhibit_rules:
  - source_match:
      severity: critical
    target_match:
      severity: warning
    equal: ['alertname', 'dev', 'instance']
```

4. Apply config:

```bash
podman cp /tmp/monitoring-alertmanager.yml monitoring-alertmanager:/etc/alertmanager/alertmanager.yml
podman exec monitoring-alertmanager kill -HUP 1
```

## Resource Tuning

### Increase Prometheus Retention

1. Edit `inventory/group_vars/monitoring/main.yml`:

```yaml
monitoring_prometheus_retention: "90d"
monitoring_prometheus_retention_size: "20GB"
```

2. Re-run provisioning.

### Increase Grafana Memory

1. Edit `roles/monitoring/templates/monitoring-pod.yml.j2` (if allowed):

```yaml
resources:
  limits:
    memory: 1G
  requests:
    memory: 512M
```

2. Re-run provisioning.

## Network Configuration

### Change Monitoring Network

1. Edit `inventory/group_vars/monitoring/main.yml`:

```yaml
monitoring_network_name: "custom-monitoring-network"
```

2. Re-run provisioning.

### Expose Ports to Host

The pod manifest binds ports to `127.0.0.1`. To expose to all interfaces:

1. Edit `roles/monitoring/templates/monitoring-pod.yml.j2` (if allowed):

```yaml
ports:
  - containerPort: 3000
    hostIP: "0.0.0.0"  # Change from 127.0.0.1
    hostPort: 3000
```

2. Re-run provisioning.

## Troubleshooting

### Check Container Status

```bash
ssh root@192.168.100.11
podman ps -a
```

### View Logs

```bash
podman logs monitoring-grafana
podman logs monitoring-prometheus
podman logs monitoring-alertmanager
```

### Check Prometheus Targets

```bash
curl -s http://127.0.0.1:9090/prometheus/api/v1/targets | jq .
```

### Check Alertmanager Config

```bash
curl -s http://127.0.0.1:9093/api/v2/status | jq .
```

### Restart Stack

```bash
podman kube play --down /etc/monitoring/monitoring-pod.yml
podman kube play --network monitoring /etc/monitoring/monitoring-pod.yml
```

### Reload Configs Without Restart

```bash
# Reload Prometheus
podman exec monitoring-prometheus kill -HUP 1

# Reload Alertmanager
podman exec monitoring-alertmanager kill -HUP 1
```

## File Locations

| Component | Config Path | Data Path |
|-----------|-------------|-----------|
| Grafana | ConfigMap (inline) | `/var/lib/monitoring/grafana` |
| Prometheus | ConfigMap (inline) | `/var/lib/monitoring/prometheus` |
| Alertmanager | ConfigMap (inline) | `/var/lib/monitoring/alertmanager` |
| mTLS Certs | `/etc/prometheus/mtls/` | — |
| Nginx | `/etc/nginx/conf.d/monitoring.conf` | — |

## ConfigMap Structure

All configuration is stored in ConfigMaps (inline in pod manifest):

- `monitoring-datasources` — Grafana datasource config
- `monitoring-dashboards-provider` — Dashboard provisioning provider
- `monitoring-dashboard-{name}` — Dashboard JSON files
- `monitoring-prometheus` — Prometheus scrape config
- `monitoring-prometheus-rules` — Alert rules
- `monitoring-alertmanager` — Alertmanager config

To update any config, edit the source file and re-run provisioning.
