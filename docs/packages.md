# packages Role

Internal package repository served by nginx on ansible04
(`packages.homelab.internal`). Replaces the former `prometheus_exporters`
role — exporter downloads merged here.

## Purpose

Centralizes binary downloads so VMs install from an internal origin instead
of upstream GitHub releases. Contents served as an autoindex vhost by the
`nginx` role.

## Repository Layout

`{{ nginx_web_root }}/packages/` (repo subdirectories created by the role):

| Directory | Contents |
|-----------|----------|
| `exporters/` | Prometheus exporter tarballs + otelcol-contrib |
| `node-exporter/textfile_scripts/` | Textfile collector scripts |
| `harbor/` | Harbor offline installer tarball |
| `rpm/` | RPM packages |
| `images/` | Container image archives |

## Exporters

Versions pinned via `packages_exporters` in
`roles/packages/defaults/main.yml` and `*_version` vars in
`inventory/group_vars/all/main.yml`:

| Exporter | Version Variable | GitHub Repo |
|----------|-----------------|-------------|
| `node_exporter` | `node_exporter_version` | `prometheus/node_exporter` |
| `pushgateway` | `pushgateway_version` | `prometheus/pushgateway` |
| `elasticsearch_exporter` | `elasticsearch_exporter_version` | `prometheus-community/elasticsearch_exporter` |
| `mysqld_exporter` | `mysqld_exporter_version` | `prometheus/mysqld_exporter` |
| `postgres_exporter` | `postgres_exporter_version` | `prometheus-community/postgres_exporter` |
| `nginx-prometheus-exporter` | `nginx_exporter_version` | `nginx/nginx-prometheus-exporter` |
| `logstash-exporter` | `logstash_exporter_version` | `kuskoman/logstash-exporter` |
| `otelcol-contrib` | `otel_collector_version` | `open-telemetry/opentelemetry-collector-releases` |

For non-standard asset names, add a `file` override in `packages_exporters`
(e.g., `nginx-prometheus-exporter` and `logstash-exporter` use custom names).

## Other Downloads

- **Harbor installer**: `packages_files` in
  `inventory/group_vars/packages/main.yml` — downloads the offline installer
  from GitHub releases to `packages/` (used by the `harbor` role).

## Upstream Check

The role queries GitHub's `releases/latest` API per exporter, compares
against the pinned version, and downloads the newer tag when available.
Rolling tags that don't match the version convention may report `NONE`.

## Report Output

After download, a report is saved to `reports/`:

- `exporters-report-YYYY-MM-DD.yml` — per-exporter current vs. latest version

## Usage

```bash
# Refresh packages + exporter report
ansible-playbook playbooks/sync-content.yml

# Deploy/update the packages repo
ansible-playbook playbooks/provision-ansible04.yml
```

## Defaults

| Variable | Default | Description |
|----------|---------|-------------|
| `packages_repo_dir` | `{{ nginx_web_root }}/packages` | Repo web root |
| `packages_exporter_arch` | `linux-amd64` | Target architecture |
| `packages_exporters` | (see above) | List of exporters to download |

## Dependencies

- `nginx` role (vhost + web root on ansible04)
