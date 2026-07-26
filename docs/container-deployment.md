# Container Deployment Patterns

Shared patterns for Podman container deployments across the homelab.

## PersistentVolumes with podman kube play

Use PV/PVC instead of hostPath for data volumes — this is the K8s-compatible pattern:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: my-app-data
spec:
  capacity:
    storage: 50Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /var/lib/elk/elasticsearch
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-app-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
```

## podman kube play — K8s Compatibility Reference

**Supported K8s kinds:** Pod, Deployment (replicas always 1), DaemonSet, Job, PersistentVolumeClaim, ConfigMap, Secret

**Supported volume types:** hostPath, emptyDir, configMap, persistentVolumeClaim, image

**Container fields supported:** name, image, ports (containerPort/hostIP/hostPort/protocol), env (value/valueFrom.*), envFrom, volumeMounts (mountPath/name/readOnly/subPath), resources (limits/requests), livenessProbe, securityContext (runAsUser/runAsGroup/readOnlyRootFilesystem/privileged/capabilities/seLinuxOptions), lifecycle.stopSignal

**Container fields NOT supported:** readinessProbe, startupProbe, tty, stdin

## Monitoring & ELK — `podman kube play`

Monitoring, Elasticsearch, Logstash, and Kibana each deploy via separate K8s YAML manifests using `podman kube play`:

1. Render Jinja2 templates to generate configs
2. Slurp static files for ConfigMap content
3. Write pod manifest with inline ConfigMaps + PersistentVolumes/PVCs
4. Run `podman kube play --down` then `podman kube play --network <name>`
5. Fix data directory ownership: grafana=472, prometheus/alertmanager=65534, elasticsearch=1000

**Configuration pattern**: All config as ConfigMaps (not hostPath mounts). PV/PVC with `ReadWriteOnce`, reclaim policy Retain.

**Inter-service communication**: All pods use `hostIP: 127.0.0.1` + `hostPort` for port mappings. Services communicate via `127.0.0.1` on the host loopback (not pod-internal DNS). Each role deploys its own independent pod.

## nginx Reverse Proxy

- Deployed on ansible01 and ansible02
- HTTPS on port 443, routes to services via sub-paths:
  - `/` → Grafana (3000)
  - `/prometheus/` → Prometheus (9090)
  - `/alertmanager/` → Alertmanager (9093)
- Bind to `127.0.0.1` via `hostIP` for internal service access

## Harbor (ansible01) — `podman-compose`

Harbor is deployed using the offline installer + prepare approach, managed by `podman-compose`:

1. Download Harbor v2.11.0 offline installer (`harbor-offline-installer-*.tgz`)
2. Extract to `/opt/harbor`, copy files to install directory
3. Load images from `harbor.{version}.tar.gz` into Podman
4. Create data directories: database, redis, registry, storage, job_logs, ca_download, config
5. Configure `harbor.yml`: hostname, admin password, TLS cert paths, Trivy (skip_update: true in offline mode), metrics port
6. Patch `docker-compose.yml` — rewrite `goharbor/*` image references to Harbor library copies, remove Podman-incompatible logging driver
7. Run `prepare --with-trivy`, then `podman-compose up -d`

**Key difference from other services**: Harbor does NOT use `podman kube play`. It uses the offline installer + prepare + podman-compose workflow.

## Troubleshooting

### Podman kube play fails

Check auth.json exists at `/root/.config/containers/auth.json`.

### Certificate errors

Verify SANs, check expiry with `openssl x509 -noout -enddate`.

### Container permissions

Run `chown -R UID:GID /path` for data directories.
