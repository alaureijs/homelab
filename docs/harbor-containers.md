# harbor_containers Role

Syncs container images from upstream registries through Harbor's proxy cache
projects, tags them into destination projects, pushes to Harbor, checks for
upstream version updates, and generates reports.

## Requirements

- Harbor v2.11+ running with proxy cache projects configured
- `podman`, `skopeo`, and `python3` on the target host
- `containers.podman` Ansible collection

## Implementation

### 1. Define Required Variables

| Variable | Type | Description |
|----------|------|-------------|
| `harbor_hostname` | string | Harbor instance FQDN (e.g., `harbor.local.lan`) |
| `harbor_sync_images` | list | Images to sync (see [Naming Convention](#naming-convention)) |
| `harbor_config_proxy_projects` | dict | Upstream registry → proxy project mapping |
| `vault_harbor_sync_password` | string | Vault-encrypted password for sync user |

### 2. Define Proxy Cache Projects

Proxy projects map upstream registries to Harbor projects. Define in
`group_vars/harbor/main.yml` (or equivalent):

```yaml
harbor_config_proxy_projects:
  docker.io: docker-hub-cache
  quay.io: quay-cache
  ghcr.io: ghcr-cache
```

The key is the upstream registry URL used in `harbor_sync_images[].registry`.
The value is the Harbor project name where the proxy cache stores images.

### 3. Define `harbor_sync_images`

Each item requires three fields:

```yaml
harbor_sync_images:
  - name: <project/image>          # e.g., library/alpine
    tag: "{{ <component>_version }}" # e.g., "{{ alpine_version }}"
    registry: <upstream-registry>   # e.g., docker.io
```

See [Naming Convention](#naming-convention) for details on how `name` controls
the Harbor path and version variable.

### 4. Include the Role

```yaml
- name: Sync container images to Harbor
  hosts: harbor-host
  roles:
    - harbor_containers
```

Or in a multi-role playbook:

```yaml
- name: Provision Harbor host
  hosts: harbor01
  roles:
    - common
    - podman
    - certificates
    - harbor
    - harbor_config
    - harbor_containers
```

## Naming Convention

The `harbor_sync_images[].name` field drives the entire sync pipeline.
The value must follow the format `<project>/<image>` where:

- **project** = first path component → becomes the Harbor destination project
- **image** = last path component → becomes the Harbor image name

```
prometheus/prometheus  →  Harbor path: harbor.local.lan/prometheus/prometheus:tag
library/alpine         →  Harbor path: harbor.local.lan/library/alpine:tag
grafana/grafana        →  Harbor path: harbor.local.lan/grafana/grafana:tag
```

### Project Derivation

The project is extracted by splitting `name` on `/` and taking the first
segment:

```
name.split('/')[0] → project
name.split('/')[-1] → short name
```

This is used in `_sync-image.yml` to tag and push:

```yaml
harbor_containers_project: "{{ item.name | regex_replace('([^/]+)/.*', '\\1') }}"
harbor_containers_short: "{{ item.name | regex_replace('.*/', '') }}"
```

So for `prometheuscommunity/elasticsearch-exporter`:

```
project: prometheuscommunity
short:   elasticsearch-exporter
Harbor:  harbor.local.lan/prometheuscommunity/elasticsearch-exporter:v1.11.0
```

### Version Variable Derivation

The `images.yml.j2` template generates a version report file
(`playbooks/reports/images.yml`) by deriving the variable name from the
short name using this rule:

```
short_name | regex_replace('-', '_') + '_version'
```

Examples:

| `name` | short name | derived variable |
|--------|------------|------------------|
| `library/alpine` | `alpine` | `alpine_version` |
| `prometheus/prometheus` | `prometheus` | `prometheus_version` |
| `grafana/grafana` | `grafana` | `grafana_version` |
| `prometheuscommunity/elasticsearch-exporter` | `elasticsearch-exporter` | `elasticsearch_exporter_version` |
| `goharbor/harbor-exporter` | `harbor-exporter` | `harbor_exporter_version` |

**Rule**: A variable named `<short_name_with_underscores>_version` must
exist in scope (e.g., in `group_vars/all/main.yml`) for the generated
`images.yml` to resolve correctly.

## Sync Pipeline

The role executes this sequence:

1. **Auth** — Writes `auth.json` with sync user credentials
2. **Pull** — Pulls each image through its registry's proxy cache project
3. **Tag** — Retags from `harbor/project/image` to `harbor/destination/image`
4. **Push** — Pushes to the destination project via `podman push`
5. **Upstream check** — Uses `skopeo list-tags` to find latest version matching
   same naming convention (v-prefix, part count, suffix)
6. **Report** — Generates YAML report with current vs. latest versions
7. **Images.yml** — Generates copy-paste-ready version file from sync results

## Report Output

After sync, reports are saved to `playbooks/reports/`:

- `sync-report-YYYY-MM-DD.yml` — Full sync report with per-image details
- `images.yml` — Version variables ready to paste into `group_vars/all/main.yml`

## Configuration

### Defaults (overridable)

| Variable | Default | Description |
|----------|---------|-------------|
| `harbor_containers_report_dir` | `/tmp/harbor-sync` | Temp dir for report files on target |
| `harbor_containers_sync_user` | `ansible-sync` | Harbor username for image push |
| `harbor_containers_auth_dir` | `/tmp/harbor-auth` | Temp dir for auth.json on target |
| `harbor_containers_local_report_dir` | `reports` | Local dir under `playbook_dir/` for fetched reports |

## Example: Complete Setup

### group_vars/all/main.yml

```yaml
# Harbor
harbor_hostname: harbor.local.lan
harbor_version: v2.11.0

# Versions (single source of truth)
alpine_version: "3.24"
grafana_version: "13.1.1"
prometheus_version: "v3.13.1"
elasticsearch_version: "9.4.4"
```

### group_vars/harbor/images.yml

```yaml
harbor_sync_images:
  - name: library/alpine
    tag: "{{ alpine_version }}"
    registry: docker.io

  - name: grafana/grafana
    tag: "{{ grafana_version }}"
    registry: docker.io

  - name: prometheus/prometheus
    tag: "{{ prometheus_version }}"
    registry: quay.io

harbor_config_proxy_projects:
  docker.io: docker-hub-cache
  quay.io: quay-cache
  ghcr.io: ghcr-cache
```

### group_vars/all/vault.yml

```yaml
vault_harbor_sync_password: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  616263...
```

### playbook.yml

```yaml
- name: Sync and update container images to Harbor
  hosts: ansible01
  become: true
  roles:
    - harbor_containers
```

Run:

```bash
ansible-playbook playbook.yml
```

## Troubleshooting

### Skopeo fails with TLS errors

Harbor uses a self-signed CA. Ensure the CA certificate is trusted:

```bash
cp /etc/pki/tls/certs/harbor.crt /etc/pki/ca-trust/source/anchors/
update-ca-trust
```

### Push fails with "unauthorized"

Check the sync user has `developer` role (not `maintainer`) in Harbor.
Verify `vault_harbor_sync_password` matches the Harbor user password.

### No upstream versions found

The upstream check matches tags with the same naming convention (v-prefix,
part count, suffix). Tags like `17-alpine` or `22-alpine` (rolling tags)
may return `NONE` if no matching pattern exists upstream.
