# harbor_containers Role

Syncs container images from upstream registries through Harbor proxy-cache
projects, tags them into destination projects, pushes to Harbor, checks for
upstream version updates, and generates reports.

This role is **read-only** toward Harbor: it never creates or modifies users,
projects, or permissions. All Harbor state must be pre-provisioned.

## Read-only Constraint

The role performs no Harbor configuration mutations:

- Writes a per-run `auth.json` for the sync user (login only, no user changes)
- Pulls images through pre-existing proxy-cache projects
- Tags and pushes images into pre-existing destination projects
- Queries upstream registries via `skopeo list-tags`
- Optionally queries the Harbor API with GET requests only (preflight)

If a required project is missing or the sync user lacks push rights, the run
fails — the role will not create the project or adjust permissions.

## Requirements

### Harbor (pre-provisioned)

- Harbor v2.11+ reachable at `harbor_hostname`
- Proxy-cache projects exist for every registry in `harbor_config_proxy_projects`
- Destination projects exist for the first path component of every image name
  (see [Naming Convention](#naming-convention))
- Sync user exists with **developer** (push) role on all destination projects
  and read (pull) access to all proxy-cache projects

### Target host

| Dependency | Required | Purpose |
|------------|----------|---------|
| `podman` | yes | image pull/tag/push (via `containers.podman` modules) |
| `python3` | yes | interpreter for registered shell output |
| `bash` | yes | shell tasks |
| `skopeo` | no | upstream latest-version check only; missing → degrades to `NONE` |

### OS compatibility

Compatible with EL 8.4+ and EL 9 (Rocky, RHEL, AlmaLinux) and Ubuntu
Desktop/Server 24.04 (noble). The role performs no package management, systemd,
firewall, or SELinux/AppArmor operations; all work happens through the
`podman`/`skopeo` CLIs.

### Requirements by distribution

| Distribution | podman | python3 | bash | skopeo (optional) | rootless extras | `ansible_python_interpreter` |
|--------------|--------|---------|------|--------------------|-----------------|------------------------------|
| EL 8.4 (Rocky/RHEL/Alma) | 1.6.x (`dnf install podman`) | 3.6.8 | preinstalled | `dnf install skopeo` | `fuse-overlayfs` + `subuid`/`subgid` ranges | `/usr/bin/python3` |
| EL 8.6+ (Rocky/RHEL/Alma) | 4.x (`dnf install podman`) | 3.6-3.12 | preinstalled | `dnf install skopeo` | `fuse-overlayfs` + `subuid`/`subgid` ranges | `/usr/bin/python3` |
| EL 9 (Rocky/RHEL/Alma) | 4.x/5.x (`dnf install podman`) | 3.9+ | preinstalled | `dnf install skopeo` | `fuse-overlayfs` + `subuid`/`subgid` ranges | `/usr/bin/python3` |
| Ubuntu 24.04 (noble) | 4.9.3 (`apt install podman`) | 3.12 | preinstalled | `apt install skopeo` | `fuse-overlayfs` + `uidmap` (auto subuid/subgid) | `/usr/bin/python3` |

```bash
# EL (Rocky / RHEL / AlmaLinux)
dnf install -y podman skopeo fuse-overlayfs
usermod --add-subuids 100000-165535 --add-subgids 100000-165535 "$USER"

# Ubuntu 24.04
apt install -y podman skopeo fuse-overlayfs uidmap
```

The role only uses `pull`/`tag`/`push` with `--authfile`/`--tls-verify`
(available since podman 1.4), so every listed podman version works. Rootless
execution is only recommended on podman >= 4 (EL 8.6+ / EL 9 / Ubuntu 24.04);
podman 1.6 on EL 8.4 has legacy cgroup handling and is best limited to rootful
sync runs. The inline registry scripts use only `re`/`json`, valid on the oldest
supported interpreter (Python 3.6).

#### EL 8.4+ / EL 9

- **podman** (AppStream): EL 8.4 ships 1.6.x, EL 8.6+ ships 4.x, EL 9 ships 4.x/5.x.
  The role only uses `pull`/`tag`/`push` with `--authfile`/`--tls-verify`
  (available since podman 1.4), so all versions work. For rootless execution,
  prefer podman >= 4 (EL 8.6+ / EL 9) — podman 1.6 on EL 8.4 has legacy cgroup
  handling and is only recommended for rootful sync runs.
- **python3** (EL 8.4 = 3.6.8): the inline registry scripts use only `re`/`json`,
  all Python 3.6-compatible and valid for ansible-core 2.17 managed nodes. Set
  `ansible_python_interpreter: /usr/bin/python3` (same as this role's homelab).
- **rootless**: requires `fuse-overlayfs` for rootless image pulls; verify
  `subuid`/`subgid` ranges for the SSH user.
- **skopeo**: available in AppStream on all supported versions.

#### Ubuntu 24.04 (noble)

- **podman** (universe, 4.9.3): rootless by default for non-root users. Install
  `podman` plus `fuse-overlayfs` and `uidmap` for rootless image pulls;
  `useradd`/`adduser` auto-allocates `subuid`/`subgid` ranges. Rootful runs
  (SSH as `root`) work out of the box.
- **python3** (3.12) and **bash**: preinstalled; the default interpreter at
  `/usr/bin/python3` satisfies `ansible_python_interpreter`.
- **skopeo**: in universe (`apt install skopeo`).
- **SELinux**: N/A — AppArmor profiles do not affect registry pull/tag/push
  operations.

### Collections

- `containers.podman` (`>= 1.7.0`)

## Variables

### Role defaults (override as needed)

| Variable | Default | Description |
|----------|---------|-------------|
| `harbor_containers_report_dir` | `/tmp/harbor-sync` | Temp dir for report files on target |
| `harbor_containers_sync_user` | `ansible-sync` | Harbor username for image push |
| `harbor_containers_sync_password` | `{{ vault_harbor_sync_password }}` | Sync user password (override to inject via extra vars / custom credential) |
| `harbor_containers_auth_dir` | `/tmp/harbor-auth` | Temp dir for auth.json on target |
| `harbor_containers_local_report_dir` | `../reports` | Local dir under `playbook_dir/` for fetched reports |
| `harbor_containers_preflight` | `false` | Run read-only Harbor API validation before sync |
| `harbor_containers_api_url` | `https://{{ harbor_hostname }}/api/v2.0` | Harbor API base URL |
| `harbor_containers_push_role_min` | `2` | Min role for destination projects (2 = developer) |
| `harbor_containers_pull_role_min` | `3` | Min role for proxy projects (3 = guest) |

### Required data variables

| Variable | Source | Description |
|----------|--------|-------------|
| `harbor_hostname` | group_vars | Harbor instance FQDN |
| `harbor_sync_images` | group_vars | Image list (see [Naming Convention](#naming-convention)) |
| `harbor_config_proxy_projects` | group_vars | Registry → proxy-cache project mapping |
| `vault_harbor_sync_password` | vault | Encrypted sync password (when not overriding `harbor_containers_sync_password`) |

## Preflight Validation

Set `harbor_containers_preflight: true` to validate Harbor state before any
pull/push. Checks are read-only GET requests against the Harbor API using the
sync user's basic-auth credentials:

- Every destination project exists and `current_user_role_id >=
  harbor_containers_push_role_min`
- Every proxy-cache project exists and `current_user_role_id >=
  harbor_containers_pull_role_min` (or the project is public)
- Missing projects, HTTP failures, and insufficient roles fail fast with a
  clear message listing all problem projects

If a project response omits `current_user_role_id`, the check degrades to
existence-only (tolerates Harbor API variants). This toggle is ideal for
CI-style runs (e.g. Ansible Automation Platform job templates) where a clean
failure before any push is preferred.

## Usage

```yaml
- name: Sync and update container images to Harbor
  hosts: ansible01
  become: true
  gather_facts: false
  roles:
    - role: harbor_containers
      harbor_containers_preflight: true
```

Facts are **not required** — report filenames use the controller date
(`strftime`), not target facts. If the play gathers facts anyway, limit them
with `gather_subset: '!all,min'` to reduce payload. `become` is optional — the
role has no root-required tasks; see
[Ansible Automation Platform](#ansible-automation-platform).

### group_vars example

```yaml
harbor_hostname: harbor.homelab.internal

harbor_sync_images:
  - name: prometheus/prometheus
    tags:
      - "{{ prometheus_version }}"
    registry: quay.io

harbor_config_proxy_projects:
  docker.io: docker-hub-cache
  quay.io: quay-cache
  ghcr.io: ghcr-cache

vault_harbor_sync_password: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  616263...
```

## Naming Convention

`harbor_sync_images[].name` drives the sync pipeline:

- **project** = first path component (`name.split('/')[0]`) → Harbor destination project
- **image** = last path component → Harbor image name
- `tags` is a list — each tag syncs independently; the first is the primary
  version used for version variables

```
prometheus/prometheus  →  harbor.homelab.internal/prometheus/prometheus:tag
library/alpine         →  harbor.homelab.internal/library/alpine:tag
```

## Sync Pipeline

1. Write `auth.json` with sync user credentials
2. Pull each image through its registry's proxy-cache project
3. Retag from `harbor/<proxy-project>/<image>` to `harbor/<destination>/<image>`
4. Push to the destination project
5. Check upstream (`skopeo list-tags`) for newer versions matching the same
   naming convention (v-prefix, part count, suffix)
6. Sync the latest upstream tag if it differs from the pinned tag
7. Generate `sync-report-YYYY-MM-DD.yml` in `reports/`

## Reports

Reports are written to the target's `harbor_containers_report_dir`, then
fetched to `{{ playbook_dir }}/{{ harbor_containers_local_report_dir }}`
(default `../reports`). Each report lists per-image `current_tag`, `latest_version`,
and `update_available`. Rolling tags (e.g. `1.31-alpine`) return `NONE` for
`latest_version` — no matching version pattern upstream.

## Ansible Automation Platform

Runs on AAP 2.x (any execution node with ansible-core ≥ 2.17).

**Collections**: install `containers.podman` via a project-root `requirements.yml`
(AAP auto-installs at project sync) or bundle it into the execution environment
with `ansible-builder`.

**Execution node role**: minimal. All Harbor API + podman work runs on the target
host; the only localhost work is the `fetch` destination directory
(`delegate_to: localhost, become: false`), which resolves to the execution node.

**Ephemeral project checkout**: `{{ playbook_dir }}/../reports` is the per-job git
clone on the execution node — fetched reports are lost on the next project update.
Set `harbor_containers_report_dir` to a persistent path (e.g. `/var/lib/harbor-sync`)
or archive reports in a job step.

**Secrets**:
- Inline `!vault |` sync password → add an Ansible Vault credential to the job
  template (re-encrypt if the new project uses a different vault password).
- Alternatively override `harbor_containers_sync_password` via extra_vars or a
  custom credential type to avoid vault entirely.

**`become` is optional**: the role has no root-required tasks (paths live in
`/tmp`, podman runs as the SSH user). For rootless execution the target needs
`subuid`/`subgid` ranges for the SSH user and the `fuse-overlayfs` package
(rootless image pulls). If the SSH user is `root`, rootful podman applies and
become is unnecessary. Choose per target; keep it consistent (mixed rootful/
rootless runs collide on the fixed `/tmp` auth/report directories).

**skopeo (optional)**: only used by the upstream latest-version check, on the
target host — never the execution node. Missing skopeo degrades silently to
`latest_version: NONE`; core sync (podman-only) is unaffected. Install via
`dnf install skopeo` on Rocky targets to enable the check.

**Preflight**: set `harbor_containers_preflight: true` for CI-style fail-fast
before any push — surfaces missing projects/permissions as a clean job failure.

**Facts**: not required — report filenames use `'%Y-%m-%d' | strftime` (controller
time). Run the play with `gather_facts: false`, or limit fact gathering to
`gather_subset: '!all,min'` if other plays need it.

## Troubleshooting

### Skopeo fails with TLS errors

Harbor uses a self-signed CA. Ensure the CA certificate is trusted:

```bash
cp /etc/pki/tls/certs/harbor.crt /etc/pki/ca-trust/source/anchors/
update-ca-trust
```

### Push fails with "unauthorized"

The sync user lacks developer role on the destination project. Re-run with
`harbor_containers_preflight: true` to identify the offending project, then have
the Harbor administrator grant the role — the role will not change permissions.

### No upstream versions found

The upstream check matches tags with the same naming convention (v-prefix, part
count, suffix). Rolling tags (`17-alpine`, `22-alpine`) return `NONE`.
