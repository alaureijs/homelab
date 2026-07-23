# prometheus_exporters Role

Downloads Prometheus exporter tarballs from GitHub releases to
`files/prometheus/exporters/`. Checks upstream for latest versions and
generates a report in `reports/`.

## Requirements

- `ansible.builtin.get_url` and `ansible.builtin.uri` modules
- Network access to `api.github.com` and GitHub release asset URLs

## Usage

```bash
ansible-playbook playbooks/download-exporters.yml
```

## Exporters

| Exporter | Version Variable | GitHub Repo |
|----------|-----------------|-------------|
| `node_exporter` | `node_exporter_version` | `prometheus/node_exporter` |
| `pushgateway` | `pushgateway_version` | `prometheus/pushgateway` |
| `elasticsearch_exporter` | `elasticsearch_exporter_version` | `prometheus-community/elasticsearch_exporter` |
| `mysqld_exporter` | `mysqld_exporter_version` | `prometheus/mysqld_exporter` |
| `postgres_exporter` | `postgres_exporter_version` | `prometheus-community/postgres_exporter` |
| `nginx-prometheus-exporter` | `nginx_exporter_version` | `nginx/nginx-prometheus-exporter` |
| `logstash-exporter` | `logstash_exporter_version` | `kuskoman/logstash-exporter` |

## Adding an Exporter

Add a version variable to `inventory/group_vars/all/main.yml` and an entry
to `prometheus_exporters` in `roles/prometheus_exporters/defaults/main.yml`:

```yaml
prometheus_exporters:
  - name: my_exporter
    version: "{{ my_exporter_version }}"
    repo: owner/repo
```

For non-standard asset names, add a `file` override:

```yaml
  - name: my-exporter
    version: "{{ my_exporter_version }}"
    repo: owner/repo
    file: "my-exporter_{{ my_exporter_version | regex_replace('^v', '') }}_linux_amd64.tar.gz"
```

## Defaults

| Variable | Default | Description |
|----------|---------|-------------|
| `prometheus_exporters_arch` | `linux-amd64` | Target architecture for downloads |
| `prometheus_exporters` | (see above) | List of exporters to download |

## Report Output

After download, reports are saved to `reports/`:

- `exporters-report-YYYY-MM-DD.yml` — Per-exporter current vs. latest version

## File Layout

```
files/prometheus/exporters/
  node_exporter-v1.12.1.linux-amd64.tar.gz
  pushgateway-v1.11.3.linux-amd64.tar.gz
  mysqld_exporter-0.19.0.linux-amd64.tar.gz
  postgres_exporter-0.20.1.linux-amd64.tar.gz
  nginx-prometheus-exporter_1.5.1_linux_amd64.tar.gz
  logstash-exporter-linux
```

## Notes

- `files/prometheus/exporters/` is in `.gitignore` — tarballs are not committed
- Versions are centralized in `inventory/group_vars/all/main.yml`
- The role runs on `localhost` via `delegate_to`
