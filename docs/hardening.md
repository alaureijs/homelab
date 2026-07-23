# Hardening

STIG and CIS Benchmark system hardening for Rocky Linux 10 VMs.

## Modules

All modules independently toggleable via `hardening_*` defaults in
`roles/hardening/defaults/main.yml`.

| Module | Default | Description |
|--------|---------|-------------|
| `hardening_sysctl` | on | Kernel/network hardening (SYN cookies, log martians, RPF) |
| `hardening_ssh_enabled` | on | SSH hardening (protocol 2, restricted ciphers/MACs) |
| `hardening_file_permissions` | on | Sticky bit, core dumps, cron ownership |
| `hardening_services` | on | Disable unnecessary services, mask rsh |
| `hardening_password_auth` | on | pwquality (minlen 14), faillock, password history |
| `hardening_auditd` | on | Audit rules (CIS 4.1) |
| `hardening_banner` | on | Login/SSH warning banners |
| `hardening_limits` | on | nofile/nproc 65536 |
| `hardening_permissions` | on | File ownership and permissions |
| `hardening_selinux` | on | Enforcing mode, application booleans |

## Disabled Services

Services disabled and masked by the hardening role:

avahi-daemon, cups, rpcbind, smb, nfs, vsftpd, dovecot, squid, ypserv,
rsh.socket, rlogin.socket, rexec.socket, telnet.socket, tftp.socket,
xinetd, bluetooth, udisks2, gssproxy, kdump, mdmonitor, sssd, rngd

## SELinux

- Mode: enforcing (persistent via `/etc/selinux/config`)
- Per-application booleans set by each role:

| Boolean | Set by | Purpose |
|---------|--------|---------|
| `container_manage_cgroup` | podman | Podman cgroup management |
| `container_read_certs` | podman | Read TLS certs from host |
| `container_manage_public_content` | podman | Access public content |
| `httpd_can_network_connect` | monitoring | nginx connects to pods |
| `httpd_can_network_relay` | monitoring | nginx relay |
| `selinuxuser_execmod` | hardening | Disabled (STIG compliance) |

## Audit Rules

Monitors: identity files, sudo, logins, file deletion, privilege escalation,
permission modifications, mounts, time/locale changes, SELinux policy.

Auditd config: 32 MB log, 5 logs, ENRICHED format, HOSTNAME labeling.

## Running

```bash
# Standalone
ansible-playbook playbooks/hardening.yml -l "harbor:monitoring"

# Part of provisioning (runs automatically)
ansible-playbook playbooks/provision-ansible01.yml
ansible-playbook playbooks/provision-ansible02.yml
```

## IP Forwarding

Disabled by default (`hardening_ip_forwarding: false`), overridden per-host
in `host_vars/*/main.yml` for Podman networking:

```yaml
hardening_ip_forwarding: true
```

## Troubleshooting

### AVC denials after hardening

Check audit log:

```bash
ausearch -m avc -ts recent
```

### Auditd won't restart

Manual restart is blocked by systemd. Use:

```bash
augenrules --load
```
