# Playbook

* [harbor-certs](harbor-certs.md) - Regenerate Harbor TLS certificates (force with certificates_force_renewal=true).
* [harbor-users](harbor-users.md) - Manage Harbor users, projects, and registries via the harbor_config role.
* [hardening](hardening.md) - Standalone STIG/CIS hardening playbook with host limit support.
* [libvirt-teardown](libvirt-teardown.md) - Destroy/undefine all libvirt lab VMs, remove ansible-net and project01 networks, delete VM disks/VARS/ISOs and cached cloud image, and clear UFW bridge rules; idempotent.
* [libvirt](libvirt.md) - Create/update libvirt VMs, ansible-net network, sdb storage pool; idempotent.
* [provision-ansible01-app](provision-ansible01-app.md) - Harbor app roles only (no common): harbor, harbor_config, harbor_containers.
* [provision-ansible01](provision-ansible01.md) - Full provisioning for the Harbor host (imports provision-common + provision-ansible01-app).
* [provision-ansible02-app](provision-ansible02-app.md) - Monitoring app roles only (no common): monitoring, firewall.
* [provision-ansible02](provision-ansible02.md) - Full provisioning for the monitoring host (imports provision-common + provision-ansible02-app).
* [provision-ansible03-app](provision-ansible03-app.md) - ELK app roles only (no common): elasticsearch, logstash, kibana.
* [provision-ansible03](provision-ansible03.md) - Full provisioning for the ELK host (imports provision-common + provision-ansible03-app).
* [provision-ansible04-app](provision-ansible04-app.md) - PKI app roles only (no common): step-ca, dns, nginx, packages.
* [provision-ansible04](provision-ansible04.md) - Full provisioning for the PKI/DNS host (imports provision-common + provision-ansible04-app).
* [provision-common](provision-common.md) - Common roles on all hosts: firewall, certificates, podman, hardening, node_exporter, otel.
* [provision-otel](provision-otel.md) - Deploy OpenTelemetry collectors on all four VMs.
* [site](site.md) - Full infrastructure provisioning: common once on all hosts, then every host app playbook, sync-content, and otel.
* [sync-content](sync-content.md) - Sync exporter tarballs, textfile scripts, and container images to Harbor; copy reports to the documents site.
