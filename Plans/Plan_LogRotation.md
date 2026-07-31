# Plan_LogRotation

Logging retention centralized in `common` role: journald 1-week retention + logrotate for application log dirs.

## Tasks

- [x] Add journald + logrotate vars to `roles/common/defaults/main.yml`
- [x] Create `roles/common/templates/journald-retention.conf.j2` and `roles/common/templates/logrotate.conf.j2`
- [x] Add tasks to `roles/common/tasks/main.yml` + `restart systemd-journald` handler
- [x] Remove logrotate blocks from `roles/harbor/tasks/main.yml` + `roles/kibana/tasks/main.yml`
- [x] Remove duplicate ELK logrotate blocks from `roles/elasticsearch/tasks/main.yml` + `roles/logstash/tasks/main.yml`
- [x] Validate: ansible-lint + `--syntax-check` on `playbooks/provision-common.yml`
- [x] Idempotency check (re-run clean)

## Decisions

- journald: `MaxRetentionSec=7day` + `SystemMaxUse=1G` via `/etc/systemd/journald.conf.d/99-retention.conf`
- logrotate: centralized `common_logrotate_configs` (harbor, elk), `rotate 7` daily, copytruncate
- Package syslog/nginx configs untouched (no double-rotation)
