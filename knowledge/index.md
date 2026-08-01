---
okf_version: "0.2"
---

# Knowledge Bundle

Knowledge wiki for the homelab infrastructure, authored in
[Open Knowledge Format v0.2](/references/okf-spec.md).

# Infrastructure

* [ansible01](/infrastructure/ansible01.md) - Harbor registry host (192.168.100.10)
* [ansible02](/infrastructure/ansible02.md) - Monitoring stack host (192.168.100.11)
* [ansible03](/infrastructure/ansible03.md) - ELK stack host (192.168.100.12)
* [ansible04](/infrastructure/ansible04.md) - PKI/DNS/portal host (192.168.100.13)
* [Network](/infrastructure/network.md) - ansible-net NAT network on the CachyOS host
* [Storage](/infrastructure/storage.md) - sdb libvirt storage pool and VM disks
* [Cloud-init](/infrastructure/cloud-init.md) - first-boot provisioning for libvirt VMs

# Services

* [Harbor](/services/harbor.md) - Container registry on ansible01
* [Monitoring](/services/monitoring.md) - Grafana/Prometheus/Alertmanager on ansible02
* [Elasticsearch](/services/elasticsearch.md) - Search and analytics engine on ansible03
* [Logstash](/services/logstash.md) - Log ingestion and transformation on ansible03
* [Kibana](/services/kibana.md) - Log exploration UI on ansible03
* [step-ca](/services/step-ca.md) - Private certificate authority on ansible04
* [DNS](/services/dns.md) - Unbound recursive resolver on ansible04
* [nginx](/services/nginx.md) - Reverse proxy and web server (portal/packages/documents)
* [OpenTelemetry](/services/otel.md) - Log collection agents on all VMs
* [Packages](/services/packages.md) - Internal package repository on ansible04

# Playbooks

* [Playbooks](/playbooks/index.md) - Provisioning, sync, and management playbooks

# Roles

* [Roles](/roles/index.md) - Ansible roles, one concept each

# Operations

* [Operations](/operations/index.md) - Cross-cutting operating procedures

# Guides

* [Guides](/guides/index.md) - Procedural and configuration manuals

# References

* [OKF Spec](/references/okf-spec.md) - Open Knowledge Format v0.2 specification
* [Actor Conventions](/references/actor-conventions.md) - Identity conventions for generated/verified
