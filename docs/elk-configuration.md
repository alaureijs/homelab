# ELK Stack Configuration Manual

This guide explains how to configure the ELK stack without modifying the role files.

## Overview

The ELK role uses variables defined in `inventory/group_vars/elk/main.yml` and `roles/elk/defaults/main.yml`. All configuration is done through these variables.

## Configuration Variables

### Elasticsearch

| Variable | Default | Description |
|----------|---------|-------------|
| `elasticsearch_heap_size` | `4g` | JVM heap size |
| `elasticsearch_cluster_name` | `elk-cluster` | Cluster name |
| `elasticsearch_http_port` | `9200` | HTTP API port |
| `elasticsearch_transport_port` | `9300` | Transport port |
| `elasticsearch_data_dir` | `/var/lib/elk/elasticsearch` | Data directory |

### Logstash

| Variable | Default | Description |
|----------|---------|-------------|
| `logstash_heap_size` | `2g` | JVM heap size |
| `logstash_http_port` | `9600` | Monitoring API port |
| `logstash_beats_port` | `5044` | Beats input port |

### Kibana

| Variable | Default | Description |
|----------|---------|-------------|
| `kibana_port` | `5601` | HTTP port |

### General

| Variable | Default | Description |
|----------|---------|-------------|
| `elk_hostname` | `observability.local.lan` | Reverse proxy hostname |
| `elk_config_dir` | `/etc/elk` | Configuration directory |
| `elk_data_dir` | `/var/lib/elk` | Data directory |
| `elk_network_name` | `elk` | Podman network name |

## How to Configure

### Step 1: Edit Group Variables

Edit `inventory/group_vars/elk/main.yml`:

```yaml
---
# ELK stack group variables

# Elasticsearch
elasticsearch_heap_size: "8g"  # Increase heap for production
elasticsearch_cluster_name: "production-cluster"

# Logstash
logstash_heap_size: "4g"  # Increase heap for high throughput

# Kibana
kibana_port: 5601

# Access
elk_kibana_url: "https://observability.local.lan/kibana/"
elk_elasticsearch_url: "https://observability.local.lan/elasticsearch/"
```

### Step 2: Run Provisioning

```bash
ansible-playbook playbooks/provision-ansible03.yml
```

## Customizing Configurations

### Elasticsearch Configuration

The Elasticsearch config is templated from `roles/elk/templates/elasticsearch.yml.j2`. To customize:

1. Create a file in `inventory/host_vars/ansible03/` (not in the role):

```yaml
# inventory/host_vars/ansible03/main.yml
elasticsearch_cluster_name: "my-custom-cluster"
elasticsearch_heap_size: "8g"
```

2. Re-run provisioning.

### Logstash Pipeline

The Logstash pipeline config is at `roles/elk/templates/logstash.conf.j2`. To add filters:

1. Create a custom pipeline file on the host:

```bash
ssh root@192.168.100.12
cat > /etc/elk/logstash/pipeline/custom.conf << 'EOF'
input {
  beats {
    port => 5044
  }
}

filter {
  if [type] == "syslog" {
    grok {
      match => { "message" => "%{SYSLOGTIMESTAMP:syslog_timestamp} %{SYSLOGHOST:syslog_hostname} %{DATA:syslog_program}(?:\[%{POSINT:syslog_pid}\])?: %{GREEDYDATA:syslog_message}" }
    }
  }
}

output {
  elasticsearch {
    hosts => ["http://elasticsearch:9200"]
    index => "%{[@metadata][beat]}-%{+YYYY.MM.dd}"
  }
}
EOF
```

2. Restart Logstash:

```bash
podman restart elk-logstash
```

### Kibana Configuration

Kibana config is at `roles/elk/templates/kibana.yml.j2`. To customize:

1. Create a custom config on the host:

```bash
ssh root@192.168.100.12
cat > /etc/elk/kibana/kibana.yml << 'EOF'
server.host: "0.0.0.0"
server.port: 5601
server.name: "kibana"
elasticsearch.hosts: ["http://elasticsearch:9200"]
monitoring.enabled: false
EOF
```

2. Restart Kibana:

```bash
podman restart elk-kibana
```

## Adding Inputs/Outputs

### Add a New Logstash Input

1. SSH to ansible03:

```bash
ssh root@192.168.100.12
```

2. Edit the pipeline config:

```bash
vi /etc/elk/logstash/pipeline/pipeline.conf
```

3. Add input:

```ruby
input {
  beats {
    port => 5044
  }
  
  # Add new input
  tcp {
    port => 5000
    codec => json
  }
}
```

4. Restart Logstash:

```bash
podman restart elk-logstash
```

### Add a New Output

1. Edit the pipeline config:

```bash
vi /etc/elk/logstash/pipeline/pipeline.conf
```

2. Add output:

```ruby
output {
  elasticsearch {
    hosts => ["http://elasticsearch:9200"]
    index => "%{[@metadata][beat]}-%{+YYYY.MM.dd}"
  }
  
  # Add new output
  file {
    path => "/var/log/logstash/%{[@metadata][beat]}-%{+YYYY.MM.dd}.log"
  }
}
```

3. Restart Logstash:

```bash
podman restart elk-logstash
```

## Resource Tuning

### Increase Elasticsearch Memory

1. Edit `inventory/group_vars/elk/main.yml`:

```yaml
elasticsearch_heap_size: "8g"
```

2. Update pod manifest memory limit in `roles/elk/templates/elk-pod.yml.j2` (if needed):

```yaml
resources:
  limits:
    memory: 10Gi
  requests:
    memory: 8Gi
```

3. Re-run provisioning.

### Increase Logstash Memory

1. Edit `inventory/group_vars/elk/main.yml`:

```yaml
logstash_heap_size: "4g"
```

2. Re-run provisioning.

## Network Configuration

### Change ELK Network

1. Edit `inventory/group_vars/elk/main.yml`:

```yaml
elk_network_name: "custom-elk-network"
```

2. Re-run provisioning.

### Expose Ports to Host

The pod manifest binds ports to `127.0.0.1`. To expose to all interfaces:

1. Edit `roles/elk/templates/elk-pod.yml.j2` (if allowed):

```yaml
ports:
  - containerPort: 9200
    hostIP: "0.0.0.0"  # Change from 127.0.0.1
    hostPort: 9200
```

2. Re-run provisioning.

## Troubleshooting

### Check Container Status

```bash
ssh root@192.168.100.12
podman ps -a
```

### View Logs

```bash
podman logs elk-elasticsearch
podman logs elk-logstash
podman logs elk-kibana
```

### Check Elasticsearch Health

```bash
curl -s http://127.0.0.1:9200/_cluster/health | jq .
```

### Check Logstash Pipeline

```bash
curl -s http://127.0.0.1:9600/_node/stats | jq .
```

### Restart Stack

```bash
podman kube play --down /etc/elk/elk-pod.yml
podman kube play --network elk /etc/elk/elk-pod.yml
chown -R 1000:1000 /var/lib/elk/elasticsearch
podman restart elk-elasticsearch
```

## File Locations

| Component | Config Path | Data Path |
|-----------|-------------|-----------|
| Elasticsearch | `/etc/elk/elasticsearch/` | `/var/lib/elk/elasticsearch/` |
| Logstash | `/etc/elk/logstash/config/` | `/var/lib/elk/logstash/` |
| Logstash Pipeline | `/etc/elk/logstash/pipeline/` | — |
| Kibana | `/etc/elk/kibana/` | — |
| Nginx | `/etc/nginx/conf.d/kibana.conf` | — |
