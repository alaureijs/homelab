#!/usr/bin/env bash

CA_URL="https://127.0.0.1:9000/health"
ROOT_CA="/etc/step-ca/certs/root_ca.crt"
INTERMEDIATE_CA="/etc/step-ca/certs/intermediate_ca.crt"

echo "# HELP step_ca_up Whether the step-ca health endpoint is reachable (1 = up, 0 = down)"
echo "# TYPE step_ca_up gauge"
if curl -sfk "$CA_URL" > /dev/null 2>&1; then
  echo "step_ca_up 1"
else
  echo "step_ca_up 0"
fi

echo "# HELP step_ca_container_running Whether the step-ca container is running (1 = running, 0 = stopped)"
echo "# TYPE step_ca_container_running gauge"
if sudo /usr/bin/podman ps --filter name=step-ca --filter status=running --format '{{.Names}}' 2>/dev/null | grep -q step-ca; then
  echo "step_ca_container_running 1"
else
  echo "step_ca_container_running 0"
fi

echo "# HELP step_ca_cert_expiry_seconds Certificate expiry in seconds from now"
echo "# TYPE step_ca_cert_expiry_seconds gauge"
for cert_file in "$ROOT_CA" "$INTERMEDIATE_CA"; do
  label=$(basename "$cert_file" .crt | tr '-' '_')
  if [ -r "$cert_file" ]; then
    expiry=$(openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | cut -d= -f2)
    if [ -n "$expiry" ]; then
      expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null)
      now_epoch=$(date +%s)
      seconds_left=$((expiry_epoch - now_epoch))
      echo "step_ca_cert_expiry_seconds{cert=\"${label}\"} ${seconds_left}"
    fi
  fi
done
