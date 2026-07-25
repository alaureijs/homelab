#!/usr/bin/env bash

LOGSTASH_API="http://localhost:9600/_node/stats"

STATS=$(curl -sf "$LOGSTASH_API" 2>/dev/null)
if [ -z "$STATS" ]; then
  echo "# HELP logstash_up Whether Logstash is reachable (1 = up, 0 = down)"
  echo "# TYPE logstash_up gauge"
  echo "logstash_up 0"
  exit 0
fi

echo "# HELP logstash_up Whether Logstash is reachable (1 = up, 0 = down)"
echo "# TYPE logstash_up gauge"
echo "logstash_up 1"

echo "# HELP logstash_events_in Total events received"
echo "# TYPE logstash_events_in counter"
echo "logstash_events_in $(echo "$STATS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('events',{}).get('in',0))")"

echo "# HELP logstash_events_out Total events emitted"
echo "# TYPE logstash_events_out counter"
echo "logstash_events_out $(echo "$STATS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('events',{}).get('out',0))")"

echo "# HELP logstash_events_filtered Total events filtered"
echo "# TYPE logstash_events_filtered counter"
echo "logstash_events_filtered $(echo "$STATS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('events',{}).get('filtered',0))")"

echo "# HELP logstash_events_duration_millis Event processing duration in milliseconds"
echo "# TYPE logstash_events_duration_millis counter"
echo "logstash_events_duration_millis $(echo "$STATS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('events',{}).get('duration_in_millis',0))")"

echo "# HELP logstash_jvm_heap_used_percent JVM heap usage percentage"
echo "# TYPE logstash_jvm_heap_used_percent gauge"
echo "logstash_jvm_heap_used_percent $(echo "$STATS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('jvm',{}).get('mem',{}).get('heap_used_percent',0))")"

echo "# HELP logstash_jvm_heap_used_bytes JVM heap used in bytes"
echo "# TYPE logstash_jvm_heap_used_bytes gauge"
echo "logstash_jvm_heap_used_bytes $(echo "$STATS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('jvm',{}).get('mem',{}).get('heap_used_in_bytes',0))")"

echo "# HELP logstash_jvm_heap_committed_bytes JVM heap committed in bytes"
echo "# TYPE logstash_jvm_heap_committed_bytes gauge"
echo "logstash_jvm_heap_committed_bytes $(echo "$STATS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('jvm',{}).get('mem',{}).get('heap_committed_in_bytes',0))")"

echo "# HELP logstash_jvm_heap_max_bytes JVM heap max in bytes"
echo "# TYPE logstash_jvm_heap_max_bytes gauge"
echo "logstash_jvm_heap_max_bytes $(echo "$STATS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('jvm',{}).get('mem',{}).get('heap_max_in_bytes',0))")"

echo "# HELP logstash_jvm_non_heap_used_bytes JVM non-heap used in bytes"
echo "# TYPE logstash_jvm_non_heap_used_bytes gauge"
echo "logstash_jvm_non_heap_used_bytes $(echo "$STATS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('jvm',{}).get('mem',{}).get('non_heap_used_in_bytes',0))")"

echo "# HELP logstash_jvm_threads_count JVM thread count"
echo "# TYPE logstash_jvm_threads_count gauge"
echo "logstash_jvm_threads_count $(echo "$STATS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('jvm',{}).get('threads',{}).get('count',0))")"

echo "# HELP logstash_jvm_threads_peak_count JVM peak thread count"
echo "# TYPE logstash_jvm_threads_peak_count gauge"
echo "logstash_jvm_threads_peak_count $(echo "$STATS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('jvm',{}).get('threads',{}).get('peak_count',0))")"

echo "# HELP logstash_jvm_gc_young_collection_count JVM young GC collection count"
echo "# TYPE logstash_jvm_gc_young_collection_count counter"
echo "logstash_jvm_gc_young_collection_count $(echo "$STATS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('jvm',{}).get('gc',{}).get('collectors',{}).get('young',{}).get('collection_count',0))")"

echo "# HELP logstash_jvm_gc_young_collection_time_millis JVM young GC collection time in milliseconds"
echo "# TYPE logstash_jvm_gc_young_collection_time_millis counter"
echo "logstash_jvm_gc_young_collection_time_millis $(echo "$STATS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('jvm',{}).get('gc',{}).get('collectors',{}).get('young',{}).get('collection_time_in_millis',0))")"

echo "# HELP logstash_jvm_gc_old_collection_count JVM old GC collection count"
echo "# TYPE logstash_jvm_gc_old_collection_count counter"
echo "logstash_jvm_gc_old_collection_count $(echo "$STATS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('jvm',{}).get('gc',{}).get('collectors',{}).get('old',{}).get('collection_count',0))")"

echo "# HELP logstash_jvm_gc_old_collection_time_millis JVM old GC collection time in milliseconds"
echo "# TYPE logstash_jvm_gc_old_collection_time_millis counter"
echo "logstash_jvm_gc_old_collection_time_millis $(echo "$STATS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('jvm',{}).get('gc',{}).get('collectors',{}).get('old',{}).get('collection_time_in_millis',0))")"

echo "# HELP logstash_jvm_uptime_millis JVM uptime in milliseconds"
echo "# TYPE logstash_jvm_uptime_millis gauge"
echo "logstash_jvm_uptime_millis $(echo "$STATS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('jvm',{}).get('uptime_in_millis',0))")"

echo "# HELP logstash_process_open_file_descriptors Number of open file descriptors"
echo "# TYPE logstash_process_open_file_descriptors gauge"
echo "logstash_process_open_file_descriptors $(echo "$STATS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('process',{}).get('open_file_descriptors',0))")"

echo "# HELP logstash_process_peak_open_file_descriptors Peak number of open file descriptors"
echo "# TYPE logstash_process_peak_open_file_descriptors gauge"
echo "logstash_process_peak_open_file_descriptors $(echo "$STATS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('process',{}).get('peak_open_file_descriptors',0))")"

echo "# HELP logstash_process_cpu_percent Process CPU usage percentage"
echo "# TYPE logstash_process_cpu_percent gauge"
echo "logstash_process_cpu_percent $(echo "$STATS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('process',{}).get('cpu',{}).get('percent',0))")"

echo "# HELP logstash_process_cpu_total_millis Total CPU time in milliseconds"
echo "# TYPE logstash_process_cpu_total_millis counter"
echo "logstash_process_cpu_total_millis $(echo "$STATS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('process',{}).get('cpu',{}).get('total_in_millis',0))")"

echo "# HELP logstash_process_virtual_memory_bytes Virtual memory in bytes"
echo "# TYPE logstash_process_virtual_memory_bytes gauge"
echo "logstash_process_virtual_memory_bytes $(echo "$STATS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('process',{}).get('mem',{}).get('total_virtual_in_bytes',0))")"

echo "# HELP logstash_queue_events Number of events in the queue"
echo "# TYPE logstash_queue_events gauge"
echo "logstash_queue_events $(echo "$STATS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('queue',{}).get('events_count',0))")"

echo "# HELP logstash_reloads_successes Number of successful pipeline reloads"
echo "# TYPE logstash_reloads_successes counter"
echo "logstash_reloads_successes $(echo "$STATS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('reloads',{}).get('successes',0))")"

echo "# HELP logstash_reloads_failures Number of failed pipeline reloads"
echo "# TYPE logstash_reloads_failures counter"
echo "logstash_reloads_failures $(echo "$STATS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('reloads',{}).get('failures',0))")"
