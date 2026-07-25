#!/usr/bin/env bash

echo "# HELP node_reboot_required Whether a reboot is required (1 = yes, 0 = no)"
echo "# TYPE node_reboot_required gauge"

sudo /usr/bin/needs-restarting -r &>/dev/null
if [ $? -ne 0 ] || [ -f /var/run/reboot-required ]; then
  echo "node_reboot_required 1"
else
  echo "node_reboot_required 0"
fi

echo "# HELP node_service_restart_required Whether a service needs restarting (1 = yes)"
echo "# TYPE node_service_restart_required gauge"

while IFS= read -r line; do
  service=$(echo "$line" | awk '{print $2}')
  [ -z "$service" ] && continue
  echo "node_service_restart_required{service=\"${service}\"} 1"
done < <(sudo /usr/bin/needs-restarting -s 2>/dev/null)
