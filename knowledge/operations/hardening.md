---
type: Guide
title: System hardening
description: STIG/CIS Benchmark hardening with 10 toggleable modules across all VMs.
tags: [hardening, security, selinux, cis]
status: stable
sources:
  - id: hardening-doc
    resource: ../../docs/hardening.md
    title: Hardening documentation
    last_modified: 2026-07-31
generated:
  by: human:alaureijs
  at: 2026-08-01T14:30:00Z
verified:
  - by: human:alaureijs
    at: 2026-08-01T14:30:00Z
---

## Modules

| Module | Default | Scope |
|--------|---------|-------|
| `hardening_sysctl` | on | SYN cookies, log martians, RPF |
| `hardening_ssh_enabled` | on | protocol 2, restricted ciphers/MACs |
| `hardening_file_permissions` | on | sticky bit, core dumps, cron ownership |
| `hardening_services` | on | disable/mask avahi, cups, rpcbind, smb, telnet, etc. |
| `hardening_password_auth` | on | pwquality (minlen 14), faillock, history |
| `hardening_auditd` | on | CIS 4.1 audit rules, 32 MB / 5 logs |
| `hardening_banner` | on | login/SSH warning banners |
| `hardening_limits` | on | nofile/nproc 65536 |
| `hardening_permissions` | on | file ownership and permissions |
| `hardening_selinux` | on | enforcing, application booleans |

## SELinux

Enforcing everywhere. Per-application booleans set by roles
(`container_manage_cgroup`, `httpd_can_network_connect`, ...). `selinuxuser_execmod`
disabled for STIG compliance. IP forwarding disabled by default, enabled
per-host where Podman needs it (`hardening_ip_forwarding: true`).[^hardening-doc]

## Running

```bash
ansible-playbook playbooks/hardening.yml -l "harbor:monitoring"
# or as part of provision-ansible0X.yml
```

## Troubleshooting

```bash
ausearch -m avc -ts recent        # AVC denials
augenrules --load                 # auditd reload (systemd restart blocked)
```

[^hardening-doc]: Hardening documentation — modules, SELinux, audit rules, troubleshooting
