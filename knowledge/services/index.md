# Service

* [Unbound DNS](dns.md) - Recursive DNS resolver on ansible04 serving homelab.internal zones with DNSSEC.
* [Elasticsearch](elasticsearch.md) - Single-node Elasticsearch serving the ELK stack and OTel log data stream on ansible03.
* [Harbor](harbor.md) - Harbor v2.11.0 container registry running on ansible01.
* [Kibana](kibana.md) - Log exploration UI on ansible03, exposed through nginx reverse proxy.
* [Logstash](logstash.md) - Log ingestion and transformation feeding Elasticsearch on ansible03.
* [Monitoring stack](monitoring.md) - Grafana, Prometheus, and Alertmanager pod on ansible02, served via nginx reverse proxy.
* [nginx reverse proxy](nginx.md) - Data-driven nginx vhosts on ansible04 serving portal, packages, and documents.
* [OpenTelemetry log collection](otel.md) - otel-collector agents on all VMs shipping journald and file logs over mTLS to ELK.
* [Packages repository](packages.md) - Internal nginx-hosted package repo on ansible04 for exporters, the Harbor installer, and textfile scripts.
* [step-ca](step-ca.md) - Private online certificate authority on ansible04 issuing 30-day certificates.
