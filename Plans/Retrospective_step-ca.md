# Retrospective: step-ca Provisioning

Lessons learned from implementing step-ca PKI, domain migration,
and package repository infrastructure. Each item documents a bug
or friction point encountered during the process, what went wrong,
and how to avoid it.

## 1. Unbound local-zone type

**Bug**: Used `host` type in `local-zone` entries. Unbound doesn't
support `host` — only `transparent`, `typetransparent`, `norecurse`,
`refuse`, `static`, `nodefault`, `inform`, `inform_deny`, `always_null`.

**Fix**: Changed to `static`.

**Prevention**: Read `unbound.conf(5)` man page before writing templates.
Verify config with `unbound-checkconf` immediately after template
render, before deploying.

## 2. step CLI flags

**Bug**: Used `--client` flag in `step ca certificate`. Flag doesn't
exist in step CLI v0.30.6.

**Fix**: Replaced with `--set extendedKeyUsage=clientAuth`.

**Prevention**: Run `step ca certificate --help` on the target CLI
version before writing Ansible tasks. Document supported flags in
role defaults.

## 3. Jinja2 list vs string type

**Bug**: Called `.split(',')` on `_cert_stepca_sans` which is already
a YAML list (Ansible variable). Lists don't have `.split()`.

**Fix**: Refactored to iterate the list directly with
`{% for san in _cert_stepca_sans %}`.

**Prevention**: When building command strings from Ansible variables,
use `set_fact` to build the command as a list of arguments rather
than string concatenation with filters. Use `command` module with
a list instead of `shell` with a string when possible.

## 4. Intermediate CA not distributed

**Bug**: Only distributed root CA to hosts. `step ca certificate`
requires both root and intermediate CA to verify the trust chain.

**Fix**: Added fetch + write of `/etc/step-ca/certs/intermediate_ca.crt`
from ansible04 to all hosts in certificates role.

**Prevention**: Document the CA chain structure in the role defaults.
The certificates role should have a test that verifies the full
chain is available before issuing certs.

## 5. Combined CA files missing intermediate

**Bug**: Both node_exporter (`ca-combined.crt`) and monitoring
(`mtls-ca-combined.crt`) contained only the root CA. Services
couldn't verify certificates signed by the intermediate CA.

**Fix**: Concatenated root + intermediate CA into combined files.
Added `cat root_ca.crt intermediate_ca.crt > ca-combined.crt`.

**Prevention**: When building combined CA files, always include the
full chain (root + intermediate). Document this requirement in
role defaults with a comment explaining the chain structure.

## 6. Monitoring role double-run

**Bug**: `monitoring/meta/main.yml` listed `certificates` as a
dependency. Since `certificates` already runs in `provision-common.yml`,
the monitoring role triggered it again, overwriting permissions.

**Fix**: Removed `certificates` from `monitoring/meta/main.yml`.

**Prevention**: Before adding role dependencies, check if the
dependency already runs in the playbook's include chain. Use
`when: false` or conditional dependencies to prevent double-runs.
Better yet: never add `certificates` as a role dependency — it
should always be called explicitly from the playbook.

## 7. node_exporter cert permissions

**Bug**: Certificates role defaulted to `0600` for `.key` files.
node_exporter service runs as `nobody` (uid 65534) and couldn't
read the key.

**Fix**: Added handler at end of play to override permissions:
certs to `0640` owned `root:node_exporter`, directory to `0750`.

**Prevention**: For services running as non-root, always specify
explicit `owner`/`group`/`mode` in the certificate definition.
Add a validation step that checks the service user can actually
read the cert/key files after issuance.

## 8. Unbound chroot + systemd type

**Bug**: Used `Type=notify` in systemd override. Unbound's chroot
blocks the sd_notify socket, so systemd never gets the "ready"
signal and keeps restarting.

**Fix**: Changed to `Type=simple`.

**Prevention**: When deploying chrooted services, always use
`Type=simple` or `Type=forking` with a PID file. Never use
`Type=notify` with chrooted services.

## 9. Root trust anchor in chrooted path

**Bug**: Generated root trust anchor at `/var/lib/unbound/root.key`.
Unbound's chroot makes it look at `/etc/unbound/var/lib/unbound/root.key`.

**Fix**: Changed path to `/etc/unbound/var/lib/unbound/root.key`.

**Prevention**: Always consider chroot paths when generating files
for chrooted services. Check `unbound.conf` for the `chroot:` directive
and prefix all paths with the chroot directory.

## 10. firewalld on ansible04

**Bug**: ansible04 had firewalld running (unlike other hosts). Port
9000 (step-ca) was blocked.

**Fix**: Opened port 9000 via `firewall-cmd --add-port=9000/tcp --permanent`.

**Prevention**: Before deploying services, check if firewalld is
running and what ports are open. Add firewall port management to
the `firewall` role with a `firewall_ports` variable per group.

## 11. aardvark-dns after harbor compose

**Bug**: Harbor's `podman-compose` creates `harbor_harbor` network.
aardvark-dns config gets wrong gateway IP, breaking DNS resolution
between containers.

**Fix**: Manual fix at
`/run/containers/networks/aardvark-dns/harbor_harbor` line 1.

**Prevention**: After `podman-compose up`, verify aardvark-dns config
matches the network's actual gateway. Consider adding a post-compose
task that patches the config.

## 12. Hardening role timeout

**Bug**: Hardening role on ansible03 caused provision playbooks to
timeout (~10 minutes on 3 hosts). The role modifies kernel parameters
that can disrupt networking.

**Fix**: Required `virsh destroy` + `virsh start` to recover.

**Prevention**: Run hardening on a single host first. Add a network
connectivity check after hardening. Consider splitting hardening
into phases with verification between each.

## 13. virsh default URI

**Bug**: `LIBVIRT_DEFAULT_URI` not set. Default resolves to session
mode, which fails for system-level operations.

**Fix**: Set `LIBVIRT_DEFAULT_URI=qemu:///system` in environment.

**Prevention**: Always set `LIBVIRT_DEFAULT_URI` in libvirt tasks.
Add to role defaults or environment section of playbooks.

## 14. node_exporter group dependency

**Bug**: `ensure-mtls-ca.yml` ran before `node_exporter` group was
created. Failed on fresh hosts.

**Fix**: Ensure node_exporter group/user exist before certificate
tasks.

**Prevention**: Document ordering dependencies between roles.
Better yet: make roles idempotent and order-independent.

## 15. podman_image pull parameter

**Bug**: `pull` parameter in `containers.podman.podman_image` expects
a boolean, not a string.

**Fix**: Used `state: present` instead.

**Prevention**: Always check module documentation for parameter types.
Use `state: present` for pulling images — it's the idiomatic way.

## 16. step ca bootstrap --root flag

**Bug**: `step ca bootstrap` doesn't accept `--root` flag. Only
`--ca-url` and `--fingerprint` are supported.

**Fix**: Removed `--root` flag. Root cert must be copied separately.

**Prevention**: Run `step ca bootstrap --help` before writing tasks.
Document supported flags in role defaults.

## 17. step-ca intermediate CA structure

**Bug**: Assumed step-ca uses a simple root CA that directly signs
certs. Actually uses root → intermediate → cert chain.

**Fix**: Distributed intermediate CA alongside root CA. Updated
combined CA file construction.

**Prevention**: Read step-ca documentation before implementation.
Understand the CA hierarchy before designing the certificate
distribution flow.

## 18. stepca cert flow on remote hosts

**Bug**: On non-ansible04 hosts, `step ca certificate` failed because
root and intermediate CAs weren't available locally.

**Fix**: Added fetch-from-ansible04 → write-to-host → bootstrap →
issue-cert flow in certificates role.

**Prevention**: Design the full certificate issuance flow before
implementation. Consider: where does the CA live? How do remote
hosts get the CA certs? What's the minimum bootstrap sequence?

## 19. Jinja2 command construction

**Bug**: Building `step ca certificate` command with string
concatenation and Jinja2 filters was fragile and hard to debug.

**Fix**: Refactored to use `set_fact` with a multi-line string
and `{% for %}` loop for SANs.

**Prevention**: For complex commands, use `ansible.builtin.command`
with a list of arguments instead of `shell` with a string. Or
use `set_fact` to build the command as a YAML list and join it.

## 20. Update-ca-trust symlink conflicts

**Bug**: `update-ca-trust extract` failed with
`ln: failed to create symbolic link` when old CA anchors existed.

**Fix**: Manual re-run usually succeeded after cleanup.

**Prevention**: Before running `update-ca-trust extract`, check for
and remove conflicting symlinks in `/etc/pki/ca-trust/source/anchors/`.

## Summary of Root Causes

| Category | Issues | Count |
|----------|--------|-------|
| Documentation not read | 1, 2, 8, 9, 16, 17 | 6 |
| Type confusion (Jinja2/Ansible) | 3, 15 | 2 |
| Incomplete chain/distribution | 4, 5, 18 | 3 |
| Role dependency ordering | 6, 14 | 2 |
| Permission mismatches | 7 | 1 |
| Environment assumptions | 10, 11, 12, 13 | 4 |
| Command construction | 19, 20 | 2 |

## Recommendations for Next Project

1. **Read the docs first**: Before writing any template or task,
   read the service's man page or configuration reference. This
   alone would have prevented 6 of 20 issues.

2. **Prototype on a single host**: Deploy to one host, verify it
   works, then roll out. The hardening timeout and firewalld issues
   would have been caught early.

3. **Test certificate chain end-to-end**: After issuing certs, verify
   the full chain with `openssl verify -CAfile ca.pem cert.pem`.
   This catches missing intermediates and permission issues.

4. **Use `ansible.builtin.command` with lists**: Avoids shell
   quoting issues and makes commands easier to debug.

5. **Document CA hierarchy in role defaults**: Add comments explaining
   root → intermediate → cert structure and which files are needed
   where.

6. **Add validation tasks**: After each major step (CA distribution,
   cert issuance, service start), add a validation task that checks
   the expected state. Fail fast instead of discovering issues later.

7. **Check firewall state**: Before deploying services, check if
   firewalld is running and what ports are open. Add this to the
   service deployment playbook.

8. **Use `changed_when` and `failed_when`**: Makes Ansible output
   cleaner and helps identify what actually changed vs. what was
   idempotent.
