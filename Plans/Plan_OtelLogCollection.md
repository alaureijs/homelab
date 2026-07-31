# Plan_OtelLogCollection

OpenTelemetry log collection (otelcol-contrib) on all 4 VMs, shipping logs over mTLS to Elasticsearch via nginx reverse proxy.

## Tasks

- [x] Repo prep: `grafana.grafana =6.1.0` in `requirements.yml`, `collections_path = collections` in `ansible.cfg`, install to `collections/`
- [x] Version pin: `otel_collector_version: "v0.157.0"` in `inventory/group_vars/all/main.yml`
- [x] Packages entry: `otelcol-contrib` in `roles/packages/defaults/main.yml` (file override for GitHub asset naming)
- [x] Inventory: `otel` group in `inventory/hosts.yml`, `inventory/group_vars/otel/main.yml` (stepca client cert via `certificates_extra`), `otel_log_paths` in host_vars
- [x] `roles/otel/` wrapper over `grafana.grafana.opentelemetry_collector` (binary from packages server, SELinux bin_t relabel, systemd-journal group, mTLS config, AVC audit)
- [x] ES prep in `roles/elasticsearch/tasks/main.yml`: ILM `otel-logs-policy` (rollover + delete 30d), component template `logs@custom` with `index.lifecycle.name`
- [x] nginx mTLS in `roles/kibana/`: combined CA build, `ssl_verify_client on` + `client_max_body_size 20m` on `/elasticsearch/`
- [x] `playbooks/provision-otel.yml`
- [x] Validate: ansible-lint (production), syntax-check otel/common/ansible03/sync-content, config render test

## Decisions

- Endpoint: `https://observability.homelab.internal/elasticsearch` (nginx → `127.0.0.1:9200`); ES `xpack.security` stays off, auth via mTLS at nginx
- mTLS: per-host `otel-client` cert (clientAuth EKU) from step-ca; combined root+intermediate CA on both sides; exporter `tls.ca_file`/`cert_file`/`key_file`
- Receivers: journald + filelog (filelog only when `otel_log_paths` non-empty)
- Processors: resourcedetection/system + batch (5s/512)
- Exporter: elasticsearch `mapping.mode: otel` → data stream `logs-generic.otel-default` (matches built-in `logs-*` template → ILM applies)
- SELinux: `/etc/otel-collector(/.*)?` → `bin_t` (pre-relabel before install so config `validate` can exec binary)
- Firewall: no changes (outbound only; 443 already open on ansible03)

## Run Order

1. `playbooks/sync-content.yml` — sync otelcol-contrib binary to packages server
2. `playbooks/provision-common.yml` — issue otel-client certs on all hosts + log rotation
3. `playbooks/provision-ansible03.yml` — ELK stack + ES ILM prep + nginx mTLS
4. `playbooks/provision-otel.yml` — deploy collectors

## Validation

- `journalctl --disk-usage`, logrotate dry-run
- collector `systemctl status otel-collector`, logs show exporter connected
- `_cat/indices` shows `logs-generic.otel-default-*` backing indices
- mTLS negative test: `curl` without client cert → 400
- AVC audit via otel role debug output
