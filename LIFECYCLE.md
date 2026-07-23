# Lifecycle Management

Version management and update procedures for all infrastructure components.

## Version Source of Truth

All component versions are defined in a single file:

```
inventory/group_vars/all/main.yml
```

This file is the **only** place to edit when bumping versions. Every role and
group variable references these variables — no hardcoded tags remain elsewhere.

### Current Versions

| Component       | Variable               | Current Value |
|-----------------|------------------------|---------------|
| Harbor          | `harbor_version`       | v2.11.0       |
| Grafana         | `grafana_version`      | 11.6.0        |
| Prometheus      | `prometheus_version`   | v3.3.0        |
| Alertmanager    | `alertmanager_version` | v0.28.1       |
| Node Exporter   | `node_exporter_version`| 1.12.1        |
| Pushgateway     | `pushgateway_version`  | v1.11.0       |
| Elasticsearch   | `elasticsearch_version`| 8.17.0        |
| Logstash        | `logstash_version`     | 8.17.0        |
| Kibana          | `kibana_version`       | 8.17.0        |
| ES Exporter     | `elasticsearch_exporter_version` | v1.11.0 |

Base images (alpine, ubuntu, nginx, etc.) are also tracked in the same file.

### How Versions Flow

```
group_vars/all/main.yml          (single source of truth)
    |
    +---> group_vars/harbor/images.yml       (tags: ["{{ grafana_version }}"])
    |         |
    |         +---> harbor_containers role   (sync images to Harbor)
    |
    +---> group_vars/monitoring/main.yml     (grafana:{{ grafana_version }})
    |         |
    |         +---> monitoring role          (pod manifest image URIs)
    |
    +---> group_vars/elk/main.yml            (elasticsearch:{{ elasticsearch_version }})
    |         |
    |         +---> elk role                 (pod manifest image URIs)
    |
    +---> roles/monitoring/defaults/main.yml (same, role defaults)
    |
    +---> roles/node_exporter/defaults/main.yml (inherits from all)
    |
    +---> roles/harbor/defaults/main.yml     (inherits from all)
```

## Update Procedures

### 1. Container Image Update (Most Common)

Update one or more container image versions (Grafana, Prometheus, etc.).

#### Pre-flight

```bash
# Check current versions
cat inventory/group_vars/all/main.yml

# Verify images exist in upstream registry
podman pull docker.io/grafana/grafana:12.0.0 --dry-run 2>&1 | head -5
# Or check tags on the registry website
```

#### Procedure

1. **Edit `group_vars/all/main.yml`** — bump the version:

   ```yaml
   grafana_version: "12.0.0"   # was 11.6.0
   ```

2. **Sync new image to Harbor** (pulls from upstream, pushes to Harbor):

   ```bash
   ansible-playbook playbooks/sync-update-containers.yml
   ```

   This pulls through the proxy cache project, tags, and pushes to the
   target Harbor project. Verify the sync report for errors.

3. **Apply monitoring stack** (redeploys pod with new image):

   ```bash
   ansible-playbook playbooks/provision-ansible02.yml --limit monitoring
   ```

   The pod manifest is re-templated and `podman kube play` restarts the
   containers with the new image.

4. **Verify**:

   ```bash
   # Check containers are running
   ssh root@192.168.100.11 'podman ps'

   # Check Prometheus targets are up
   curl -sk -u admin:Harbor12345 https://monitoring.local.lan/prometheus/api/v1/targets | \
     python3 -c "import sys,json; [print(f\"{t['labels'].get('job','?')}: {t['health']}\") for t in json.load(sys.stdin)['data']['activeTargets']]"

   # Check Grafana is accessible
   curl -sk -o /dev/null -w '%{http_code}' https://monitoring.local.lan/grafana/
   ```

5. **Update CHANGELOG.md** and commit.

#### Rollback

If the new version has issues:

```bash
# Revert main.yml
git checkout HEAD~1 -- inventory/group_vars/all/main.yml

# Redeploy
ansible-playbook playbooks/provision-ansible02.yml --limit monitoring
```

The old image is still in Harbor (images are never deleted automatically),
so the pod will pull the previous version.

### 2. Harbor Platform Update

Update Harbor itself (v2.11.0 → v2.12.0, etc.).

#### Pre-flight

- Read the Harbor release notes for breaking changes
- Check disk space: `df -h /data/harbor`
- Back up Harbor data: `sudo tar czf /tmp/harbor-backup-$(date +%F).tar.gz /data/harbor`
- Verify the new offline installer URL exists

#### Procedure

1. **Edit `group_vars/all/main.yml`**:

   ```yaml
   harbor_version: "v2.12.0"   # was v2.11.0
   ```

2. **Download the new offline installer** to ansible01:

   ```bash
   ansible-playbook playbooks/provision-ansible01.yml --limit ansible01
   ```

   The harbor role downloads the installer, runs `prepare`, patches
   compose, and restarts containers. This is idempotent.

3. **Verify Harbor health**:

   ```bash
   curl -sk -u admin:Harbor12345 https://harbor.local.lan/api/v2.0/health
   ```

4. **Re-sync images** (some updates change image compatibility):

   ```bash
   ansible-playbook playbooks/sync-update-containers.yml
   ```

5. **Update CHANGELOG.md** and commit.

#### Rollback

```bash
# Stop Harbor
ssh root@192.168.100.10 'cd /opt/harbor && podman-compose down'

# Revert main.yml
git checkout HEAD~1 -- inventory/group_vars/all/main.yml

# Reinstall previous version
ansible-playbook playbooks/provision-ansible01.yml --limit ansible01

# Restore data backup if needed
```

### 3. Node Exporter Binary Update

Update the node_exporter binary installed on all hosts.

#### Procedure

1. **Edit `group_vars/all/main.yml`**:

   ```yaml
   node_exporter_version: "1.13.0"   # was 1.12.1
   ```

2. **Apply** (runs on all hosts in the provisioning playbook):

   ```bash
   ansible-playbook playbooks/provision-ansible02.yml
   ```

   The node_exporter role detects the version change, downloads the new
   binary, installs it, and restarts the service.

3. **Verify**:

   ```bash
   # Check service is running on both hosts
   ssh root@192.168.100.10 'systemctl status node-exporter --no-pager | head -5'
   ssh root@192.168.100.11 'systemctl status node-exporter --no-pager | head -5'

   # Check Prometheus shows targets as up (wait ~30s for scrape)
   curl -sk -u admin:Harbor12345 https://monitoring.local.lan/prometheus/api/v1/targets | \
     python3 -c "import sys,json; [print(f\"{t['labels'].get('job','?')}: {t['health']}\") for t in json.load(sys.stdin)['data']['activeTargets']]"
   ```

4. **Update CHANGELOG.md** and commit.

### 4. Base Image Update

Update base images synced to Harbor (alpine, nginx, postgres, etc.).

#### Procedure

1. **Edit `group_vars/all/main.yml`** — bump the version:

   ```yaml
   alpine_version: "3.22"
   nginx_version: "1.28-alpine"
   ```

2. **Sync to Harbor**:

   ```bash
   ansible-playbook playbooks/sync-update-containers.yml
   ```

3. **Update CHANGELOG.md** and commit.

   No deployment is needed — base images are synced for offline use and
   consumed by other projects/teams.

## Checking for Updates

The sync playbook includes an update check that compares current tags
against upstream registries:

```bash
ansible-playbook playbooks/sync-update-containers.yml --check
```

This reports available updates without actually pulling/pushing. The check
matches tags with the same naming convention (v-prefix, part count, suffix)
to avoid false positives from distroless/variant tags.

## Certificate Renewal

Certificates are automatically renewed when they expire within a configurable
threshold. The default threshold is 30 days.

### How It Works

Both the `certificates` role (host TLS) and `monitoring` role (mTLS) check
certificate expiry on every playbook run:

1. Read the existing certificate's `notAfter` date
2. Calculate days until expiry
3. If expiry is within the threshold, regenerate the certificate
4. If the certificate doesn't exist, generate a new one

For the monitoring mTLS stack, the CA renewal cascades — if the monitoring CA
is renewed, the node-exporter server cert and Prometheus client cert are also
regenerated (they're signed by the CA).

### Variables

| Variable                            | Default | Description                                   |
|-------------------------------------|---------|-----------------------------------------------|
| `certificates_renew_threshold_days` | 30      | Host cert renewal threshold (days before expiry) |
| `certificates_force_renewal`        | false   | Force host cert renewal regardless of expiry   |
| `monitoring_cert_renew_threshold_days` | 30   | mTLS cert renewal threshold (days before expiry) |
| `monitoring_cert_force_renewal`     | false   | Force mTLS cert renewal regardless of expiry   |

### Automatic Renewal

No action needed — certificates are renewed on the next playbook run when
they're within 30 days of expiry. The default threshold can be adjusted in
`roles/certificates/defaults/main.yml` and `roles/monitoring/defaults/main.yml`.

### Force Renewal

Force immediate certificate renewal regardless of expiry. Useful after:
- Changing SANs (e.g., adding a new DNS name)
- Suspected key compromise
- Changing certificate subject fields

```bash
# Force renew host certificates on all hosts
ansible-playbook playbooks/provision-ansible02.yml -e certificates_force_renewal=true

# Force renew monitoring mTLS certificates
ansible-playbook playbooks/provision-ansible02.yml -e monitoring_cert_force_renewal=true

# Force renew everything
ansible-playbook playbooks/provision-ansible02.yml \
  -e certificates_force_renewal=true \
  -e monitoring_cert_force_renewal=true
```

### Verify Certificate Expiry

Check when a certificate expires:

```bash
# Host certificate
openssl x509 -in /etc/pki/tls/certs/ansible02.crt -noout -enddate

# Monitoring CA
openssl x509 -in /etc/prometheus/mtls/ca.crt -noout -enddate

# Node-exporter server cert
openssl x509 -in /etc/pki/tls/certs/node-exporter.crt -noout -enddate

# Prometheus client cert
openssl x509 -in /etc/prometheus/mtls/client.crt -noout -enddate
```

### Harbor Certificates

Harbor certificates are regenerated separately:

```bash
ansible-playbook playbooks/harbor-certs.yml
```

To force renewal with a custom threshold:

```bash
ansible-playbook playbooks/harbor-certs.yml -e certificates_force_renewal=true
```

## Harbor User Management

Users, projects, and roles are managed via the `harbor_config` role:

```bash
ansible-playbook playbooks/harbor-users.yml
```

To add a new user, edit `inventory/group_vars/harbor/main.yml`:

```yaml
harbor_config_users:
  - username: new-user
    password: "{{ vault_new_user_password }}"
    realname: "New User"
    email: new-user@local.lan
    roles:
      - project_name: library
        role_id: 3   # guest
```

Encrypt the password first:

```bash
ansible-vault encrypt_string 'my-password' --name 'vault_new_user_password'
```

## Adding New Container Images

To sync a new image to Harbor:

1. Add to `inventory/group_vars/harbor/images.yml`:

   ```yaml
   harbor_sync_images:
     - name: library/new-image
       tags:
         - "{{ new_image_version }}"
       registry: docker.io
   ```

2. Add the version variable to `inventory/group_vars/all/main.yml`:

   ```yaml
   new_image_version: "1.0"
   ```

3. Run the sync:

   ```bash
   ansible-playbook playbooks/sync-update-containers.yml
   ```

4. Projects are auto-discovered when `harbor_config_sync_projects: true`
   (no manual project creation needed).

## Troubleshooting

### Container fails to start after version bump

```bash
# Check container logs
ssh root@192.168.100.11 'podman logs monitoring-prometheus 2>&1 | tail -20'

# Check if image was pulled correctly
ssh root@192.168.100.11 'podman images | grep grafana'
```

### Prometheus targets down after update

```bash
# Check target status and errors
curl -sk -u admin:Harbor12345 https://monitoring.local.lan/prometheus/api/v1/targets | \
  python3 -c "import sys,json; [print(f\"{t['labels'].get('job','?')}: {t['health']} err={t.get('lastError','')}\") for t in json.load(sys.stdin)['data']['activeTargets']]"
```

### node-exporter not scraping

```bash
# Verify node-exporter is listening on host IP
ssh root@192.168.100.10 'ss -tlnp | grep 9100'

# Test mTLS connection from ansible02
ssh root@192.168.100.11 'curl -s --cacert /etc/pki/tls/certs/monitoring-ca.crt \
  --cert /etc/prometheus/mtls/client.crt \
  --key /etc/prometheus/mtls/client.key \
  https://192.168.100.10:9100/metrics | head -2'
```

### Harbor API errors

```bash
# Check Harbor health
curl -sk -u admin:Harbor12345 https://harbor.local.lan/api/v2.0/health

# Check Trivy scanner status
curl -sk -u admin:Harbor12345 https://harbor.local.lan/api/v2.0/systeminfo/vulnerabilities
```
