#!/usr/bin/env bash

convert_bytes() {
  local val="$1"
  local num unit
  num=$(echo "$val" | grep -oP '[0-9.]+')
  unit=$(echo "$val" | grep -oP '[A-Za-z]+')
  case "$unit" in
    B)    echo "$num" | awk '{printf "%.0f", $1}' ;;
    KiB|kB)  echo "$num" | awk '{printf "%.0f", $1 * 1024}' ;;
    MiB|MB)  echo "$num" | awk '{printf "%.0f", $1 * 1024 * 1024}' ;;
    GiB|GB)  echo "$num" | awk '{printf "%.0f", $1 * 1024 * 1024 * 1024}' ;;
    TiB|TB)  echo "$num" | awk '{printf "%.0f", $1 * 1024 * 1024 * 1024 * 1024}' ;;
    *)    echo "0" ;;
  esac
}

PS_FILE="/var/lib/node-exporter/textfiles_metrics/.ch_ps.txt"
STATS_FILE="/var/lib/node-exporter/textfiles_metrics/.ch_stats.txt"
sudo /usr/bin/podman ps -a --format '{{.Names}}|{{.Image}}|{{.State}}|{{.Status}}' > "$PS_FILE" 2>/dev/null
sudo /usr/bin/podman stats --no-stream --format '{{.Name}},{{.CPUPerc}},{{.MemUsage}},{{.MemLimit}},{{.NetIO}},{{.BlockIO}}' > "$STATS_FILE" 2>/dev/null

echo "# HELP node_container_state Whether a container is running (1 = running, 0 = stopped)"
echo "# TYPE node_container_state gauge"
echo "# HELP node_container_health Container health status (1 = healthy, 0 = unhealthy, -1 = no healthcheck)"
echo "# TYPE node_container_health gauge"
echo "# HELP node_container_cpu_percentage CPU usage percentage"
echo "# TYPE node_container_cpu_percentage gauge"
echo "# HELP node_container_memory_usage_bytes Memory usage in bytes"
echo "# TYPE node_container_memory_usage_bytes gauge"
echo "# HELP node_container_memory_limit_bytes Memory limit in bytes"
echo "# TYPE node_container_memory_limit_bytes gauge"
echo "# HELP node_container_network_input_bytes Network input bytes"
echo "# TYPE node_container_network_input_bytes gauge"
echo "# HELP node_container_network_output_bytes Network output bytes"
echo "# TYPE node_container_network_output_bytes gauge"
echo "# HELP node_container_block_input_bytes Block I/O input bytes"
echo "# TYPE node_container_block_input_bytes gauge"
echo "# HELP node_container_block_output_bytes Block I/O output bytes"
echo "# TYPE node_container_block_output_bytes gauge"

while IFS='|' read -r name image state status; do
  name=$(echo "$name" | xargs)
  image=$(echo "$image" | xargs)
  state=$(echo "$state" | xargs)
  status=$(echo "$status" | xargs)

  [ -z "$name" ] && continue
  [[ "$name" == *-infra ]] && continue

  if [ "$state" = "running" ]; then
    echo "node_container_state{name=\"${name}\",image=\"${image}\"} 1"
  else
    echo "node_container_state{name=\"${name}\",image=\"${image}\"} 0"
  fi

  if echo "$status" | grep -q "(healthy)"; then
    echo "node_container_health{name=\"${name}\",image=\"${image}\"} 1"
  elif echo "$status" | grep -q "(unhealthy)"; then
    echo "node_container_health{name=\"${name}\",image=\"${image}\"} 0"
  else
    echo "node_container_health{name=\"${name}\",image=\"${image}\"} -1"
  fi
done < "$PS_FILE"

while IFS=',' read -r name cpu mem_usage mem_limit net_io block_io; do
  [ -z "$name" ] && continue
  [[ "$name" == *-infra ]] && continue

  image=$(grep "^${name}|" "$PS_FILE" | cut -d'|' -f2 | xargs)
  [ -z "$image" ] && continue

  cpu_val=$(echo "$cpu" | tr -d '% ' | awk '{printf "%.2f", $1}')

  mem_used=$(echo "$mem_usage" | awk -F'/' '{print $1}' | xargs)
  mem_bytes=$(convert_bytes "$mem_used")

  limit_bytes=$(echo "$mem_limit" | xargs)

  net_in_raw=$(echo "$net_io" | awk -F'/' '{print $1}' | xargs)
  net_out_raw=$(echo "$net_io" | awk -F'/' '{print $2}' | xargs)
  net_in_bytes=$(convert_bytes "$net_in_raw")
  net_out_bytes=$(convert_bytes "$net_out_raw")

  block_in_raw=$(echo "$block_io" | awk -F'/' '{print $1}' | xargs)
  block_out_raw=$(echo "$block_io" | awk -F'/' '{print $2}' | xargs)
  block_in_bytes=$(convert_bytes "$block_in_raw")
  block_out_bytes=$(convert_bytes "$block_out_raw")

  echo "node_container_cpu_percentage{name=\"${name}\",image=\"${image}\"} ${cpu_val}"
  echo "node_container_memory_usage_bytes{name=\"${name}\",image=\"${image}\"} ${mem_bytes}"
  echo "node_container_memory_limit_bytes{name=\"${name}\",image=\"${image}\"} ${limit_bytes}"
  echo "node_container_network_input_bytes{name=\"${name}\",image=\"${image}\"} ${net_in_bytes}"
  echo "node_container_network_output_bytes{name=\"${name}\",image=\"${image}\"} ${net_out_bytes}"
  echo "node_container_block_input_bytes{name=\"${name}\",image=\"${image}\"} ${block_in_bytes}"
  echo "node_container_block_output_bytes{name=\"${name}\",image=\"${image}\"} ${block_out_bytes}"
done < "$STATS_FILE"

rm -f "$PS_FILE" "$STATS_FILE"
