# Ansible Role

* [certificates](certificates.md) - Issue and deploy TLS certificates from step-ca with SANs, auto-renewal within 30 days.
* [common](common.md) - Install base packages, chrony, journald retention, step-cli; shared OS baseline.
* [dns](dns.md) - Configure Unbound local zones for homelab.internal with DNSSEC.
* [elasticsearch](elasticsearch.md) - Deploy Elasticsearch + exporter pod (host network) with PV/PVC.
* [firewall](firewall.md) - Firewalld rules for services; UFW bridge rules for the libvirt host.
* [harbor](harbor.md) - Install and configure Harbor registry via offline installer + prepare + podman-compose.
* [harbor_config](harbor_config.md) - Configure Harbor users, projects, and registries via the v2.0 API.
* [harbor_containers](harbor_containers.md) - Sync container images to Harbor through proxy-cache projects or directly upstream; read-only toward Harbor.
* [hardening](hardening.md) - STIG/CIS Benchmark hardening with 10 toggleable modules.
* [kibana](kibana.md) - Deploy Kibana pod + nginx reverse proxy; mTLS-gated /elasticsearch/ endpoint.
* [libvirt](libvirt.md) - Provision libvirt VMs, storage pool, ansible-net, cloud-init ISOs on the CachyOS host.
* [logstash](logstash.md) - Deploy Logstash pod (host network) with beats input, grok filters, ES output.
* [monitoring](monitoring.md) - Deploy Grafana, Prometheus, Alertmanager pod via podman kube play with ConfigMaps.
* [nginx](nginx.md) - Install nginx and generate data-driven vhosts from nginx_vhosts + vhost.conf.j2.
* [node_exporter](node_exporter.md) - Install node-exporter binary, systemd service, mTLS web config, textfile collectors.
* [otel](otel.md) - Install otelcol-contrib collector; ships journald + file logs over mTLS to ELK.
* [packages](packages.md) - Download exporters, Harbor installer, and textfile scripts to the internal package repo.
* [podman](podman.md) - Install Podman, Buildah, Skopeo, podman-compose and configure registries.conf.
* [step-ca](step-ca.md) - Deploy Smallstep step-ca v0.30.2 as a Podman container; PKI init, JWK + ACME provisioners.
