# Plan: step-ca + ca-portal + DNS Roles + PKI Migration + Domain Migration

- [x] Phase 0: Domain Migration (`local.lan` → `homelab.internal`)
- [x] Phase 1: New VM + Inventory
- [ ] Phase 2: step-ca role
- [ ] Phase 3: ca-portal role
- [ ] Phase 4: DNS role (Unbound)
- [ ] Phase 5: Playbooks
- [ ] Phase 6: Replace certificates infrastructure
- [ ] Phase 7: Service certificate migration
- [ ] Phase 8: Role updates
- [ ] Phase 9: Variables
- [ ] Phase 10: Documentation
- [ ] Phase 11: Cleanup

## Decisions

| Decision | Value |
|----------|-------|
| Internal domain | `homelab.internal` (IANA-reserved RFC 6761) |
| Previous domain | `local.lan` (deprecated, non-standard) |
| Deployment host | ansible04 (192.168.100.13, new VM) |
| Deployment method | Podman container (`podman kube play`) |
| step-ca version | v0.30.2 (pinned) |
| step-cli version | v0.30.6 (pinned) |
| CA strategy | Replace existing mTLS CA entirely |
| Cert consumers | All services (Harbor, monitoring, ELK, node-exporter, nginx) |
| Default cert duration | 30 days |
| step CLI scope | All hosts |
| CA backup | Yes — root CA key to controller, vault-encrypted |
| Webserver | New `ca-portal` role (nginx, serves root CA + ACME) |
| DNS server | Unbound (dnf, native binary) |
| DNS mode | Static `local-zone`/`local-data` for internal, forward to upstream |
| DNSSEC | Enabled (root trust anchor via `auto-trust-anchor-file`) |
| DHCP DNS | All VMs get 192.168.100.13 as nameserver |

## Phase 0: Domain Migration (`local.lan` → `homelab.internal`)

### Strategy

1. **Add dual-domain SANs first** — add `homelab.internal` SANs to all
   hosts, force-renew ALL certs (both `local.lan` AND `homelab.internal`)
2. **Verify services** — confirm both domains work before any config changes
3. **Config/DNS changes one host at a time** — update inventory, templates,
   DNS entries per host; re-provision and verify each
4. **Final cleanup** — remove old `local.lan` SANs after all hosts migrated

**Migration order**: ansible01 (Harbor) → ansible02 (Monitoring) → ansible03 (ELK)

**Certificate strategy**: Step 0.0 adds dual-domain SANs and renews ALL
certs at once. Steps 0.5-0.7 only re-provision for config/DNS changes
(no cert renewal). Step 0.9 removes old `local.lan` SANs and renews again.

**DNS strategy**: Controller `/etc/hosts` gets both old and new FQDNs
during transition. Libvirt dnsmasq gets both old and new entries from
`vm_dns_entries`. After all hosts migrated, old entries removed.

### New FQDNs

| Old | New |
|-----|-----|
| `harbor.local.lan` | `harbor.homelab.internal` |
| `monitoring.local.lan` | `monitoring.homelab.internal` |
| `observability.local.lan` | `observability.homelab.internal` |
| `ansible01.local.lan` | `ansible01.homelab.internal` |
| `ansible02.local.lan` | `ansible02.homelab.internal` |
| `ansible03.local.lan` | `ansible03.homelab.internal` |
| `ca.local.lan` (new) | `ca.homelab.internal` |
| `pki.local.lan` (new) | `pki.homelab.internal` |

### Step 0.0: Add dual-domain SANs and renew all certificates

Before any config/DNS changes, add `homelab.internal` SANs to ALL
certificates and force-renew. This gives every service fresh, valid
certs with BOTH domains. All subsequent steps only change config/DNS —
no cert renewal needed until Step 0.9 (cleanup).

#### 0a: Update dual-domain SANs in inventory

- [x] `inventory/group_vars/harbor/main.yml:42-43` — update (currently has `DNS:{{ harbor_hostname }}`):
  ```yaml
  certificates_extra_sans:
    - "DNS:harbor.local.lan"
    - "DNS:harbor.homelab.internal"
    - "IP:192.168.100.10"
  ```
- [x] `inventory/group_vars/monitoring/main.yml:3-4` — update (currently has `DNS:monitoring.local.lan`):
  ```yaml
  certificates_extra_sans:
    - "DNS:monitoring.local.lan"
    - "DNS:monitoring.homelab.internal"
  ```
- [x] `inventory/group_vars/elk/main.yml` — add new `certificates_extra_sans`:
  ```yaml
  certificates_extra_sans:
    - "DNS:observability.local.lan"
    - "DNS:observability.homelab.internal"
  ```

> **Note**: The mTLS client cert on ansible02 also needs `extra_sans` with
> FQDNs for Prometheus mTLS to work. Updated `certificates_extra` in
> `monitoring/main.yml` to include `DNS:{{ vm_hostname }}`,
> `DNS:{{ vm_hostname }}.{{ lab_domain }}`, `DNS:{{ vm_hostname }}.homelab.internal`.

#### 0b: Force-renew all certs on all hosts

```bash
ansible-playbook playbooks/provision-ansible01.yml -e certificates_force_renewal=true
ansible-playbook playbooks/provision-ansible02.yml -e certificates_force_renewal=true
ansible-playbook playbooks/provision-ansible03.yml -e certificates_force_renewal=true
```

#### 0c: Verify services healthy with dual-domain certs

```bash
# Harbor — both domains
curl -sk https://harbor.local.lan/api/v2.0/health
curl -sk https://harbor.homelab.internal/api/v2.0/health

# Monitoring — both domains
curl -sk -o /dev/null -w '%{http_code}' https://monitoring.local.lan/grafana/
curl -sk -o /dev/null -w '%{http_code}' https://monitoring.homelab.internal/grafana/
curl -sk https://monitoring.local.lan/prometheus/api/v1/targets | \
  python3 -c "import sys,json; [print(f\"{t['labels'].get('job','?')}: {t['health']}\") for t in json.load(sys.stdin)['data']['activeTargets']]"

# ELK — both domains
curl -sk -o /dev/null -w '%{http_code}' https://observability.local.lan/kibana/
curl -sk -o /dev/null -w '%{http_code}' https://observability.homelab.internal/kibana/
curl -sk https://observability.local.lan/elasticsearch/_cluster/health | python3 -m json.tool
```

#### 0d: Verify cert SANs show both domains

```bash
# ansible01
ssh root@192.168.100.10 'openssl x509 -in /etc/pki/tls/certs/ansible01.crt -noout -text | grep -A1 "Subject Alternative Name"'
ssh root@192.168.100.10 'openssl x509 -in /etc/pki/tls/certs/harbor.crt -noout -text | grep -A1 "Subject Alternative Name"'
ssh root@192.168.100.10 'openssl x509 -in /etc/node-exporter/node-exporter.crt -noout -text | grep -A1 "Subject Alternative Name"'

# ansible02
ssh root@192.168.100.11 'openssl x509 -in /etc/pki/tls/certs/ansible02.crt -noout -text | grep -A1 "Subject Alternative Name"'
ssh root@192.168.100.11 'openssl x509 -in /etc/prometheus/mtls/client.crt -noout -text | grep -A1 "Subject Alternative Name"'
ssh root@192.168.100.11 'openssl x509 -in /etc/node-exporter/node-exporter.crt -noout -text | grep -A1 "Subject Alternative Name"'

# ansible03
ssh root@192.168.100.12 'openssl x509 -in /etc/pki/tls/certs/ansible03.crt -noout -text | grep -A1 "Subject Alternative Name"'
ssh root@192.168.100.12 'openssl x509 -in /etc/node-exporter/node-exporter.crt -noout -text | grep -A1 "Subject Alternative Name"'
```

Expected: Every cert shows BOTH `local.lan` AND `homelab.internal` SANs.

#### Gate criteria

All of the following must be true before proceeding to Step 0.1:
- [x] All services return expected HTTP status codes on BOTH domains
- [x] All Prometheus targets show `up`
- [x] All cert SANs show both `local.lan` AND `homelab.internal`
- [x] No cert expiry warnings within 30 days

### Step 0.1: Update global inventory

These variables affect all hosts — update first.

- [x] 0.1.1 `inventory/group_vars/all/main.yml:6` — `lab_domain: homelab.internal`
- [x] 0.1.2 `inventory/group_vars/all/main.yml:9` — `harbor_hostname: harbor.homelab.internal`
- [x] 0.1.3 `inventory/group_vars/all/main.yml:99-101` — controller hosts entries (BOTH domains):
  ```yaml
  controller_hosts_entries:
    - "192.168.100.10 ansible01 ansible01.local.lan ansible01.homelab.internal harbor.local.lan harbor.homelab.internal"
    - "192.168.100.11 ansible02 ansible02.local.lan ansible02.homelab.internal monitoring.local.lan monitoring.homelab.internal"
    - "192.168.100.12 ansible03 ansible03.local.lan ansible03.homelab.internal observability.local.lan observability.homelab.internal"
  ```
- [x] 0.1.4 `inventory/group_vars/harbor/main.yml:57,83,109,135` — email addresses → `@homelab.internal`

### Step 0.2: Update host_vars (dual DNS entries)

Add new domain entries while keeping old ones. Libvirt dnsmasq serves both.

- [x] 0.2.1 `inventory/host_vars/ansible01/main.yml:12-14`:
  ```yaml
  vm_dns_entries:
    - name: harbor.local.lan
      ip: 192.168.100.10
    - name: harbor.homelab.internal
      ip: 192.168.100.10
  ```
- [x] 0.2.2 `inventory/host_vars/ansible02/main.yml:17-19`:
  ```yaml
  vm_dns_entries:
    - name: monitoring.local.lan
      ip: 192.168.100.11
    - name: monitoring.homelab.internal
      ip: 192.168.100.11
  ```
- [x] 0.2.3 `inventory/host_vars/ansible03/main.yml:17-19`:
  ```yaml
  vm_dns_entries:
    - name: observability.local.lan
      ip: 192.168.100.12
    - name: observability.homelab.internal
      ip: 192.168.100.12
  ```

### Step 0.3: Update role defaults and templates

- [x] 0.3.1 `roles/monitoring/defaults/main.yml:4` — `monitoring_hostname: monitoring.homelab.internal`
- [x] 0.3.2 `roles/kibana/templates/nginx-kibana.conf.j2:4,40` — `server_name` gets BOTH domains:
  ```nginx
  server_name observability.local.lan observability.homelab.internal;
  ```
- [x] 0.3.3 `roles/libvirt/templates/user-data.j2:33-34` — DNS search domains:
  ```yaml
  - nmcli connection modify "System eth0" ipv4.dns-search "{{ vm_hostname }}.homelab.internal"
  - nmcli connection modify "System eth0" ipv4.dns-search "homelab.internal"
  ```

### Step 0.4: Update controller /etc/hosts

Push both old and new FQDNs to controller:

```bash
ansible-playbook playbooks/provision-common.yml
```

Verify both domains resolve:

```bash
getent hosts harbor.local.lan
getent hosts harbor.homelab.internal
getent hosts monitoring.local.lan
getent hosts monitoring.homelab.internal
getent hosts observability.local.lan
getent hosts observability.homelab.internal
```

### Step 0.5: Migrate ansible01 (Harbor)

Config/DNS changes only — certs already have dual-domain SANs from Step 0.0.

- [x] Update `inventory/host_vars/ansible01/main.yml` DNS entries (see Step 0.2)
- [x] Update `inventory/group_vars/harbor/main.yml` email addresses (see Step 0.1)

Re-provision (no cert renewal — already done):

```bash
ansible-playbook playbooks/provision-ansible01.yml
```

Verify:

```bash
curl -sk https://harbor.homelab.internal/api/v2.0/health
curl -sk https://harbor.local.lan/api/v2.0/health
```

### Step 0.6: Migrate ansible02 (Monitoring)

Config/DNS changes only — certs already have dual-domain SANs from Step 0.0.

- [x] Update `inventory/host_vars/ansible02/main.yml` DNS entries (see Step 0.2)
- [x] Update `roles/monitoring/defaults/main.yml:4` — `monitoring_hostname: monitoring.homelab.internal`

Re-provision (no cert renewal):

```bash
ansible-playbook playbooks/provision-ansible02.yml
```

Verify:

```bash
curl -sk -o /dev/null -w '%{http_code}' https://monitoring.homelab.internal/grafana/
curl -sk -o /dev/null -w '%{http_code}' https://monitoring.local.lan/grafana/
curl -sk https://monitoring.homelab.internal/prometheus/api/v1/targets | \
  python3 -c "import sys,json; [print(f\"{t['labels'].get('job','?')}: {t['health']}\") for t in json.load(sys.stdin)['data']['activeTargets']]"
```

**Note**: Prometheus scrape targets now use `{{ lab_domain }}` (homelab.internal).
node-exporter targets update automatically. Verify all targets are `up`.

### Step 0.7: Migrate ansible03 (ELK)

Config/DNS changes only — certs already have dual-domain SANs from Step 0.0.

- [x] Update `inventory/host_vars/ansible03/main.yml` DNS entries (see Step 0.2)
- [x] `inventory/group_vars/elk/main.yml:14` — `elk_hostname: observability.homelab.internal`
- [x] `inventory/group_vars/elk/main.yml:17-18` — URLs use new domain
- [x] `roles/kibana/templates/nginx-kibana.conf.j2:4,40` — `server_name` gets BOTH domains:
  ```nginx
  server_name observability.local.lan observability.homelab.internal;
  ```

Re-provision (no cert renewal):

```bash
ansible-playbook playbooks/provision-ansible03.yml
```

Verify:

```bash
curl -sk -o /dev/null -w '%{http_code}' https://observability.homelab.internal/kibana/
curl -sk -o /dev/null -w '%{http_code}' https://observability.local.lan/kibana/
curl -sk https://observability.homelab.internal/elasticsearch/_cluster/health | python3 -m json.tool
```

### Step 0.8: Verify full infrastructure

All three hosts migrated with dual-domain certs. Both domains work.

```bash
# All services via new domain
curl -sk https://harbor.homelab.internal/api/v2.0/health
curl -sk -o /dev/null -w '%{http_code}' https://monitoring.homelab.internal/grafana/
curl -sk https://monitoring.homelab.internal/prometheus/api/v1/targets | \
  python3 -c "import sys,json; [print(f\"{t['labels'].get('job','?')}: {t['health']}\") for t in json.load(sys.stdin)['data']['activeTargets']]"
curl -sk -o /dev/null -w '%{http_code}' https://observability.homelab.internal/kibana/

# All services via old domain (should still work)
curl -sk https://harbor.local.lan/api/v2.0/health
curl -sk -o /dev/null -w '%{http_code}' https://monitoring.local.lan/grafana/
curl -sk -o /dev/null -w '%{http_code}' https://observability.local.lan/kibana/

# Prometheus all targets up
curl -sk https://monitoring.homelab.internal/prometheus/api/v1/targets | \
  python3 -c "
import sys, json
data = json.load(sys.stdin)
for t in data['data']['activeTargets']:
    print(f\"{t['labels'].get('job','?'):20s} {t['health']:10s} {t['scrapeUrl']}\")"
```

### Step 0.9: Cleanup — remove old domain SANs

After verifying both domains work, remove `local.lan` SANs from
certificates. This is a separate step — do NOT combine with migration.

#### 9a: Remove dual-domain SANs from inventory

- [ ] Remove `certificates_extra_sans` from `inventory/group_vars/harbor/main.yml`
- [ ] Remove `certificates_extra_sans` from `inventory/group_vars/monitoring/main.yml`
- [ ] Remove `certificates_extra_sans` from `inventory/group_vars/elk/main.yml`

#### 9b: Remove old domain entries from host_vars

- [ ] `inventory/host_vars/ansible01/main.yml` — remove `harbor.local.lan` entry
- [ ] `inventory/host_vars/ansible02/main.yml` — remove `monitoring.local.lan` entry
- [ ] `inventory/host_vars/ansible03/main.yml` — remove `observability.local.lan` entry

#### 9c: Remove old domain from controller hosts entries

- [ ] `inventory/group_vars/all/main.yml:99-101` — remove old FQDNs:
  ```yaml
  controller_hosts_entries:
    - "192.168.100.10 ansible01 ansible01.homelab.internal harbor.homelab.internal"
    - "192.168.100.11 ansible02 ansible02.homelab.internal monitoring.homelab.internal"
    - "192.168.100.12 ansible03 ansible03.homelab.internal observability.homelab.internal"
  ```

#### 9d: Remove old domain from nginx-kibana template

- [ ] `roles/kibana/templates/nginx-kibana.conf.j2:4,40` — remove `observability.local.lan`:
  ```nginx
  server_name observability.homelab.internal;
  ```

#### 9e: Re-provision all hosts with new certs (no old SANs)

```bash
ansible-playbook playbooks/provision-ansible01.yml -e certificates_force_renewal=true
ansible-playbook playbooks/provision-ansible02.yml -e certificates_force_renewal=true
ansible-playbook playbooks/provision-ansible03.yml -e certificates_force_renewal=true
```

#### 9f: Verify new certs have only homelab.internal SANs

```bash
ssh root@192.168.100.10 'openssl x509 -in /etc/pki/tls/certs/harbor.crt -noout -text | grep -A1 "Subject Alternative Name"'
ssh root@192.168.100.11 'openssl x509 -in /etc/pki/tls/certs/monitoring.crt -noout -text | grep -A1 "Subject Alternative Name"'
ssh root@192.168.100.12 'openssl x509 -in /etc/pki/tls/certs/kibana.crt -noout -text | grep -A1 "Subject Alternative Name"'
```

Expected: Only `homelab.internal` SANs, no `local.lan`.

#### 9g: Final verification

```bash
# New domain works
curl -sk https://harbor.homelab.internal/api/v2.0/health
curl -sk -o /dev/null -w '%{http_code}' https://monitoring.homelab.internal/grafana/
curl -sk -o /dev/null -w '%{http_code}' https://observability.homelab.internal/kibana/

# Old domain fails (expected — no more local.lan SANs)
curl -sk https://harbor.local.lan/api/v2.0/health 2>&1 | head -1
# Expected: SSL certificate problem: unable to get local issuer certificate
```

### Step 0.10: Final cleanup

- [ ] 0.10.1 Remove old DNS entries from libvirt network (regenerated on next `libvirt.yml` run)
- [ ] 0.10.2 Remove old entries from controller `/etc/hosts` (done by 9c + provision-common)
- [ ] 0.10.3 Verify no `local.lan` references remain (except CHANGELOG.md)

```bash
# Final check — should only return CHANGELOG.md and Plan migration table
grep -r "local\.lan" --include="*.yml" --include="*.j2" --include="*.md" . | \
  grep -v CHANGELOG.md | grep -v "Plans/Plan_step-ca.md" | grep -v "Phase 0"
```

### Rollback

If a host breaks during migration:

1. **Revert inventory for that host**:
   ```bash
   git checkout HEAD~1 -- inventory/group_vars/<group>/main.yml inventory/host_vars/<host>/main.yml
   ```

2. **Re-provision that host**:
   ```bash
   ansible-playbook playbooks/provision-ansible0X.yml -e certificates_force_renewal=true
   ```

3. **Verify old domain still works**:
   ```bash
   curl -sk https://<service>.local.lan/<endpoint>
   ```

## Phase 1: New VM + Inventory

- [x] 1.1 Add `pki` group + `ansible04` to `inventory/hosts.yml`
- [x] 1.2 Create `inventory/host_vars/ansible04/main.yml` (IP, MAC, hostname, DNS, specs)
- [x] 1.3 Add `ansible04` to `controller_hosts_entries` in `inventory/group_vars/all/main.yml`
- [x] 1.4 Add `ansible04` to `libvirt` group
- [x] 1.5 Update `roles/libvirt/templates/network.xml.j2` — DHCP DNS to 192.168.100.13
- [x] 1.6 Add `ansible04` DNS entry to `ansible-net` network

## Phase 2: step-ca Role

- [ ] 2.1 Create role scaffold: `defaults/`, `tasks/`, `templates/`, `handlers/`, `meta/`, `molecule/`
- [ ] 2.2 `defaults/main.yml` — version, paths, ports, provisioners, cert durations, backup settings
- [ ] 2.3 `tasks/main.yml` — install step-cli, pull image, init CA, configure provisioners (JWK + ACME), start pod, backup root CA to controller
- [ ] 2.4 `templates/ca.json.j2` — step-ca server config (address, DNS, provisioners, claims, DB)
- [ ] 2.5 `templates/step-ca-pod.yml.j2` — K8s YAML for `podman kube play` (container, PV/PVC, volume mounts)
- [ ] 2.6 `templates/step-ca.service.j2` — systemd unit (oneshot, podman kube play up/down)
- [ ] 2.7 `handlers/main.yml` — restart step-ca (podman kube play --down && up)
- [ ] 2.8 `meta/main.yml` — depends on `podman`, `certificates`
- [ ] 2.9 Add `step_ca_version` and `step_cli_version` to `inventory/group_vars/all/main.yml`
- [ ] 2.10 Add `vault_stepca_password` + `vault_stepca_provisioner_password` to vault
- [ ] 2.11 Create `inventory/group_vars/pki/main.yml` with step-ca + ca-portal vars
- [ ] 2.12 Molecule tests (default, minimum scenarios)

### Default Variables

```yaml
# roles/step-ca/defaults/main.yml
step_ca_version: "0.30.2"
step_cli_version: "0.30.6"
step_ca_image: "smallstep/step-ca:{{ step_ca_version }}"
step_ca_hostname: ca.homelab.internal
step_ca_port: 9000
step_ca_data_dir: /var/lib/step-ca
step_ca_config_dir: /etc/step-ca
step_ca_name: "Lab CA"
step_ca_password: "{{ vault_stepca_password }}"
step_ca_provisioner_name: admin
step_ca_provisioner_password: "{{ vault_stepca_provisioner_password }}"

step_ca_min_cert_duration: "5m"
step_ca_default_cert_duration: "720h"   # 30 days
step_ca_max_cert_duration: "2160h"      # 90 days

step_ca_provisioners:
  - name: admin
    type: JWK
  - name: acme
    type: ACME

step_ca_backup_enabled: true
step_ca_backup_dir: "{{ playbook_dir }}/../files/step-ca"
```

## Phase 3: ca-portal Role

- [ ] 3.1 Create role scaffold: `defaults/`, `tasks/`, `templates/`, `files/`, `handlers/`, `meta/`
- [ ] 3.2 `defaults/main.yml` — hostname, ports, SSL settings, web roots
- [ ] 3.3 `tasks/main.yml` — install nginx, deploy CA certs to web root, deploy vhost, deploy portal page, ensure nginx running
- [ ] 3.4 `templates/ca-portal.conf.j2` — nginx vhost (port 80 ACME + redirect, port 443 portal)
- [ ] 3.5 `templates/index.html.j2` — portal landing page (CA name, fingerprint, download links, bootstrap commands)
- [ ] 3.6 `handlers/main.yml` — reload nginx
- [ ] 3.7 `meta/main.yml` — depends on `step-ca`, `certificates`

### Default Variables

```yaml
# roles/ca-portal/defaults/main.yml
ca_portal_hostname: pki.homelab.internal
ca_portal_http_port: 80
ca_portal_https_port: 443
ca_portal_ssl_cert: /etc/pki/tls/certs/ca-portal.crt
ca_portal_ssl_key: /etc/pki/tls/private/ca-portal.key
ca_portal_web_root: /var/www/ca-portal
ca_portal_ca_dir: /var/www/ca
ca_portal_acme_dir: /var/www/acme
```

### nginx Config Structure

```nginx
# Port 80 — ACME + redirect
server {
    listen 80;
    server_name {{ ca_portal_hostname }};

    location /.well-known/acme-challenge/ {
        root {{ ca_portal_acme_dir }};
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

# Port 443 — CA Portal
server {
    listen 443 ssl;
    server_name {{ ca_portal_hostname }};

    ssl_certificate     {{ ca_portal_ssl_cert }};
    ssl_certificate_key {{ ca_portal_ssl_key }};

    location /ca/ {
        alias {{ ca_portal_ca_dir }}/;
        add_header Content-Disposition "attachment";
        add_header Content-Type "application/x-x509-ca-cert";
    }

    location /acme/ {
        proxy_pass https://127.0.0.1:{{ step_ca_port }};
    }

    location / {
        root {{ ca_portal_web_root }};
        index index.html;
    }
}
```

## Phase 4: DNS Role (Unbound)

- [ ] 4.1 Create role scaffold: `defaults/`, `tasks/`, `templates/`, `handlers/`, `meta/`, `molecule/`
- [ ] 4.2 `defaults/main.yml` — listen address, upstream forwarders, local zones, DNSSEC settings
- [ ] 4.3 `tasks/main.yml` — install unbound, deploy config, deploy local zones, enable service
- [ ] 4.4 `templates/unbound.conf.j2` — main config (server block, forward zones, DNSSEC, access control)
- [ ] 4.5 `templates/local-zones.conf.j2` — `local-zone` and `local-data` entries for all hosts + services
- [ ] 4.6 `templates/forward-zones.conf.j2` — upstream forwarders (Cloudflare 1.1.1.1, Google 8.8.8.8)
- [ ] 4.7 `handlers/main.yml` — restart unbound
- [ ] 4.8 `meta/main.yml` — no dependencies (DNS is foundational)
- [ ] 4.9 Add `unbound_version` (if pinning) to `inventory/group_vars/all/main.yml`
- [ ] 4.10 Create `inventory/group_vars/pki/main.yml` DNS vars (if separated from phase 2.11)
- [ ] 4.11 Molecule tests (default, minimum scenarios)

### Default Variables

```yaml
# roles/dns/defaults/main.yml
dns_listen_addresses:
  - "127.0.0.1"
  - "{{ hostvars[inventory_hostname]['vm_ip'] | default('0.0.0.0') }}"

dns_interface: eth0
dns_port: 53

dns_upstream_forwarders:
  - "1.1.1.1"
  - "1.0.0.1"
  - "8.8.8.8"
  - "8.8.4.4"

dns_access_control:
  - subnet: "192.168.100.0/24"
    permission: allow

dns_domain: homelab.internal

dns_local_zones:
  - name: ansible01.homelab.internal
    type: host
    address: 192.168.100.10
  - name: ansible02.homelab.internal
    type: host
    address: 192.168.100.11
  - name: ansible03.homelab.internal
    type: host
    address: 192.168.100.12
  - name: ansible04.homelab.internal
    type: host
    address: 192.168.100.13
  - name: harbor.homelab.internal
    type: host
    address: 192.168.100.10
  - name: monitoring.homelab.internal
    type: host
    address: 192.168.100.11
  - name: observability.homelab.internal
    type: host
    address: 192.168.100.12
  - name: ca.homelab.internal
    type: host
    address: 192.168.100.13
  - name: pki.homelab.internal
    type: host
    address: 192.168.100.13

dns_dnssec_enabled: true
dns_dnssec_anchor_file: /var/lib/unbound/root.key
dns_dnssec_module: "validator iterator"

dns_cache_size: "64m"
dns_msg_cache_size: "32m"
dns_prefetch: true
dns_harden_glue: true
dns_harden_dnssec_stripped: true
dns_use_caps_for_id: false
```

### Unbound Config Structure

```yaml
# templates/unbound.conf.j2
server:
  interface: {{ dns_listen_addresses | join(' ') if dns_listen_addresses | length > 1 else dns_listen_addresses[0] }}
  port: {{ dns_port }}
  access-control: {{ dns_access_control | map(attribute='subnet') | zip(dns_access_control | map(attribute='permission')) | map('join', ' ') | join(', ') }}
  # DNSSEC
  module-config: "{{ dns_dnssec_module }}"
  auto-trust-anchor-file: {{ dns_dnssec_anchor_file }}
  val-clean-additional: yes
  val-permissive-mode: no
  # Performance
  msg-cache-size: {{ dns_msg_cache_size }}
  rrset-cache-size: {{ dns_cache_size }}
  prefetch: {{ dns_prefetch | ternary('yes', 'no') }}
  # Security
  harden-glue: {{ dns_harden_glue | ternary('yes', 'no') }}
  harden-dnssec-stripped: {{ dns_harden_dnssec_stripped | ternary('yes', 'no') }}
  use-caps-for-id: {{ dns_use_caps_for_id | ternary('yes', 'no') }}
  # Logging
  verbosity: 1
  log-queries: no
  log-replies: no

# Forward FQDN queries to upstream — bare hostnames stay local
# Only queries with a dot (i.e., a domain) are forwarded.
# Bare hostnames (e.g., "harbor") are resolved from local-zones only.
forward-zone:
  name: "."
{% for fwd in dns_upstream_forwarders %}
  forward-addr: {{ fwd }}
{% endfor %}
```

### Forwarding Behavior

Unbound applies this resolution order:

1. **Local zones first**: `local-zone`/`local-data` entries for `homelab.internal`
2. **Forward FQDNs**: Queries with a dot (e.g., `github.com`) forwarded to upstream (1.1.1.1, 8.8.8.8)
3. **Bare hostnames stay local**: Queries without a dot (e.g., `harbor`) resolve from local-zones only — **no forwarding**

This means:
- `harbor.homelab.internal` → resolved from local-zones
- `github.com` → forwarded to upstream
- `harbor` (bare) → resolves from local-zones if defined, otherwise NXDOMAIN
- No search domain expansion on the server side — clients must use FQDNs

### Local Zones Template

```yaml
# templates/local-zones.conf.j2
# Internal host resolution — single source of truth
# Managed by Ansible, do not edit manually
# All entries MUST be FQDNs (ending with .homelab.internal)
# Bare hostnames are NOT forwarded upstream — only FQDNs are resolved
{% for zone in dns_local_zones %}
local-zone: "{{ zone.name }}." {{ zone.type }}
local-data: "{{ zone.name }}. IN A {{ zone.address }}"
{% endfor %}
```

### DNSSEC Details

DNSSEC validation is enabled on Unbound to verify external DNS responses:

- **Root trust anchor**: `/var/lib/unbound/root.key` (auto-maintained by `unbound-anchor`)
- **Module config**: `module-config: "validator iterator"` enables DNSSEC validation
- **Strict mode**: `harden-dnssec-stripped: yes` — drops responses with missing DNSSEC signatures
- **Internal zones**: Served as plain A records (no DNSSEC signing needed for local zones)
- **Forwarding**: Only FQDNs (queries with a dot) are forwarded upstream; bare hostnames stay local

```bash
# Check DNSSEC validation
dig +dnssec github.com
dig +cd github.com          # bypass validation (comparison)
unbound-control lookup github.com
```

### systemd Service

```bash
systemctl enable --now unbound
unbound-control reload
```

### Management Commands

```bash
# Check config
unbound-checkconf /etc/unbound/unbound.conf

# Reload config
unbound-control reload

# Flush cache
unbound-control flush_zone .

# Check DNSSEC status
unbound-control lookup google.com

# View stats
unbound-control stats_noreset
```

### Bootstrap

On ansible04 only:
1. Install unbound via `dnf`
2. Deploy config + local zones from templates
3. Generate root.key: `unbound-anchor -a /var/lib/unbound/root.key`
4. Start service
5. Verify DNSSEC validation works
6. Update libvirt network DHCP DNS to point to ansible04

**Dependency**: DNS must be up before step-ca starts (step-ca uses hostnames in its config).

## Phase 5: Playbooks

- [ ] 5.1 Create `playbooks/provision-ansible04.yml` (order: common → step-ca → ca-portal)
- [ ] 5.2 Update `playbooks/provision-common.yml` — replace `ensure-mtls-ca.yml` import with step-ca CA distribution
- [ ] 5.3 Delete `playbooks/ensure-mtls-ca.yml`
- [ ] 5.4 Update `playbooks/harbor-certs.yml` — remove ensure-mtls-ca import

## Phase 6: Replace Certificates Infrastructure

- [ ] 6.1 Add `stepca` type to `roles/certificates/tasks/generate.yml` — uses `step ca certificate` CLI
- [ ] 6.2 Add step-cli bootstrap task to `roles/certificates/tasks/main.yml`
- [ ] 6.3 Distribute step-ca root CA cert to all hosts (replace mTLS CA distribution)
- [ ] 6.4 Add step-ca root CA to system trust store on all hosts

## Phase 7: Service Certificate Migration

- [ ] 7.1 Harbor (ansible01) — `certificates` selfsigned → `stepca` type
- [ ] 7.2 Monitoring nginx (ansible02) — `certificates` selfsigned → `stepca` type
- [ ] 7.3 ELK/nginx (ansible03) — `certificates` selfsigned → `stepca` type
- [ ] 7.4 node-exporter mTLS (all) — `ensure-mtls-ca.yml` ownca → `stepca` type
- [ ] 7.5 Prometheus mTLS client (ansible02) — `ensure-mtls-ca.yml` ownca → `stepca` type
- [ ] 7.6 ca-portal (ansible04) — self-signed bootstrap → `stepca` type after step-ca is up

## Phase 8: Role Updates

- [ ] 8.1 `certificates` — add `stepca` cert type, `step-cli` bootstrap, step-ca URL/fingerprint vars
- [ ] 8.2 `harbor` — update cert paths, trust step-ca root CA
- [ ] 8.3 `monitoring` — update nginx cert paths, mTLS client cert from step-ca
- [ ] 8.4 `kibana` — update nginx cert paths
- [ ] 8.5 `node_exporter` — server cert from step-ca
- [ ] 8.6 `common` — add step-ca root CA to system trust store
- [ ] 8.7 `dns` — add Unbound role to all hosts' DNS config (update `/etc/resolv.conf` via NetworkManager or dhclient)

## Phase 9: Variables

- [ ] 9.1 Add `vault_stepca_password` + `vault_stepca_provisioner_password` to vault
- [ ] 9.2 Create `inventory/group_vars/pki/main.yml`
- [ ] 9.3 Update `inventory/group_vars/all/main.yml` — add versions, replace mTLS paths, update `lab_domain`
- [ ] 9.4 Update per-group cert definitions to use `stepca` type

## Phase 10: Documentation

- [ ] 10.1 Create `docs/pki-step-ca.md` — update with `homelab.internal`, add DNS section
- [ ] 10.2 Update `AGENTS.md` — add step-ca + DNS to architecture diagram, roles table
- [ ] 10.3 Update `LIFECYCLE.md` — add step-ca version management
- [ ] 10.4 Update all docs — replace `local.lan` → `homelab.internal`

## Phase 11: Cleanup

- [ ] 11.1 Delete `playbooks/ensure-mtls-ca.yml`
- [ ] 11.2 Remove old mTLS CA files from `files/certificates/mtls-ca.*`
- [ ] 11.3 Remove mTLS-related vars from `group_vars/all/main.yml`
- [ ] 11.4 Update `roles/harbor/meta/main.yml` dependencies
- [ ] 11.5 Verify no `local.lan` references remain (except CHANGELOG.md historical entries)

## Dependency Graph

```
Phase 0 (Domain Migration)
    |
    v
Phase 1 (VM/Inventory)
    |
    v
Phase 4 (DNS role) -----> Phase 2 (step-ca role) ---+
    |                          |                      |
    v                          v                      v
Phase 3 (ca-portal)      Phase 6 (certificates)   Phase 5 (playbooks)
    |                          |                      |
    v                          v                      v
Phase 7 (service migration) <------------------------+
    |
    v
Phase 8 (role updates) --> Phase 9 (vars) --> Phase 10 (docs) --> Phase 11 (cleanup)
```

## Files Created (net new)

| File | Purpose |
|------|---------|
| `roles/step-ca/defaults/main.yml` | step-ca default variables |
| `roles/step-ca/tasks/main.yml` | CA deployment tasks |
| `roles/step-ca/tasks/distribute-ca.yml` | Root CA distribution to all hosts |
| `roles/step-ca/templates/ca.json.j2` | step-ca server config |
| `roles/step-ca/templates/step-ca-pod.yml.j2` | Podman K8s manifest |
| `roles/step-ca/templates/step-ca.service.j2` | Systemd service unit |
| `roles/step-ca/handlers/main.yml` | Restart handler |
| `roles/step-ca/meta/main.yml` | Role metadata |
| `roles/ca-portal/defaults/main.yml` | Portal default variables |
| `roles/ca-portal/tasks/main.yml` | Nginx + portal deployment |
| `roles/ca-portal/templates/ca-portal.conf.j2` | Nginx vhost config |
| `roles/ca-portal/templates/index.html.j2` | CA portal landing page |
| `roles/ca-portal/handlers/main.yml` | Nginx reload handler |
| `roles/ca-portal/meta/main.yml` | Role metadata |
| `roles/dns/defaults/main.yml` | Unbound default variables |
| `roles/dns/tasks/main.yml` | Unbound deployment tasks |
| `roles/dns/templates/unbound.conf.j2` | Unbound main config |
| `roles/dns/templates/local-zones.conf.j2` | Internal DNS records |
| `roles/dns/templates/forward-zones.conf.j2` | Upstream forwarders |
| `roles/dns/handlers/main.yml` | Restart handler |
| `roles/dns/meta/main.yml` | Role metadata |
| `inventory/host_vars/ansible04/main.yml` | ansible04 host vars |
| `inventory/group_vars/pki/main.yml` | PKI group variables |
| `playbooks/provision-ansible04.yml` | ansible04 provisioning playbook |
| `docs/pki-step-ca.md` | Requirements documentation |

## Files Modified

| File | Changes |
|------|---------|
| `inventory/hosts.yml` | Add `pki` group + ansible04 |
| `inventory/group_vars/all/main.yml` | Add versions, replace mTLS paths, update `lab_domain` |
| `inventory/group_vars/all/vault.yml` | Add vault passwords |
| `inventory/group_vars/harbor/main.yml` | Update cert definitions, email domains |
| `inventory/group_vars/monitoring/main.yml` | Update cert definitions, hostname |
| `inventory/group_vars/elk/main.yml` | Update hostname, URLs |
| `inventory/host_vars/ansible01/main.yml` | Update DNS entry |
| `inventory/host_vars/ansible02/main.yml` | Update DNS entry |
| `inventory/host_vars/ansible03/main.yml` | Update DNS entry |
| `roles/monitoring/defaults/main.yml` | Update default hostname |
| `roles/kibana/templates/nginx-kibana.conf.j2` | Update server_name |
| `roles/libvirt/templates/user-data.j2` | Update DNS search domains |
| `roles/libvirt/templates/network.xml.j2` | DHCP DNS to 192.168.100.13 |
| `roles/certificates/tasks/main.yml` | Add step-cli bootstrap |
| `roles/certificates/tasks/generate.yml` | Add `stepca` cert type |
| `roles/certificates/defaults/main.yml` | Add step-ca vars |
| `roles/harbor/meta/main.yml` | Update dependencies |
| `playbooks/provision-common.yml` | Replace ensure-mtls-ca |
| `playbooks/provision-ansible01.yml` | Add step-ca trust |
| `playbooks/provision-ansible02.yml` | Add step-ca trust |
| `playbooks/provision-ansible03.yml` | Add step-ca trust |
| `playbooks/harbor-certs.yml` | Remove ensure-mtls-ca |
| `AGENTS.md` | Update architecture + roles |
| `LIFECYCLE.md` | Add step-ca version management |
| `README.md` | Update domain references |

## Files Deleted

| File | Reason |
|------|--------|
| `playbooks/ensure-mtls-ca.yml` | Replaced by step-ca CA distribution |
| `files/certificates/mtls-ca.crt` | Old mTLS CA |
| `files/certificates/mtls-ca.key` | Old mTLS CA key |

## Files NOT Updated (historical)

| File | Reason |
|------|--------|
| `CHANGELOG.md` | Historical entries preserved as-is |
