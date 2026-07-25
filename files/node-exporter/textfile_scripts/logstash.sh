#!/usr/bin/env bash

curl -sf "http://localhost:9198/metrics" 2>/dev/null || {
  echo "# HELP logstash_up Whether Logstash exporter is reachable (1 = up, 0 = down)"
  echo "# TYPE logstash_up gauge"
  echo "logstash_up 0"
}
