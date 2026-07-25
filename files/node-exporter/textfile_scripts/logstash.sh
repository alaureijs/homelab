#!/usr/bin/env bash

STATS=$(curl -sf "http://localhost:9600/_node/stats" 2>/dev/null)
if [ -z "$STATS" ]; then
  echo "# HELP logstash_up Whether Logstash is reachable (1 = up, 0 = down)"
  echo "# TYPE logstash_up gauge"
  echo "logstash_up 0"
  exit 0
fi

echo "$STATS" | python3 -c '
import sys, json

d = json.load(sys.stdin)

def g(obj, *keys, default=0):
    for k in keys:
        if isinstance(obj, dict):
            obj = obj.get(k, default)
        else:
            return default
    return obj or default

def m(name, help_text, typ, value, labels=None):
    print(f"# HELP {name} {help_text}")
    print(f"# TYPE {name} {typ}")
    lbl = ""
    if labels:
        pairs = ",".join(f"{k}=\"{v}\"" for k, v in labels.items())
        lbl = "{" + pairs + "}"
    print(f"{name}{lbl} {value}")

m("logstash_up", "Whether Logstash is reachable (1 = up, 0 = down)", "gauge", 1)

m("logstash_events_in", "Total events received", "counter", g(d, "events", "in"))
m("logstash_events_out", "Total events emitted", "counter", g(d, "events", "out"))
m("logstash_events_filtered", "Total events filtered", "counter", g(d, "events", "filtered"))
m("logstash_events_duration_millis", "Event processing duration in milliseconds", "counter", g(d, "events", "duration_in_millis"))

m("logstash_jvm_heap_used_percent", "JVM heap usage percentage", "gauge", g(d, "jvm", "mem", "heap_used_percent"))
m("logstash_jvm_heap_used_bytes", "JVM heap used in bytes", "gauge", g(d, "jvm", "mem", "heap_used_in_bytes"))
m("logstash_jvm_heap_committed_bytes", "JVM heap committed in bytes", "gauge", g(d, "jvm", "mem", "heap_committed_in_bytes"))
m("logstash_jvm_heap_max_bytes", "JVM heap max in bytes", "gauge", g(d, "jvm", "mem", "heap_max_in_bytes"))
m("logstash_jvm_non_heap_used_bytes", "JVM non-heap used in bytes", "gauge", g(d, "jvm", "mem", "non_heap_used_in_bytes"))
m("logstash_jvm_threads_count", "JVM thread count", "gauge", g(d, "jvm", "threads", "count"))
m("logstash_jvm_threads_peak_count", "JVM peak thread count", "gauge", g(d, "jvm", "threads", "peak_count"))

m("logstash_jvm_gc_young_collection_count", "JVM young GC collection count", "counter", g(d, "jvm", "gc", "collectors", "young", "collection_count"))
m("logstash_jvm_gc_young_collection_time_millis", "JVM young GC collection time in milliseconds", "counter", g(d, "jvm", "gc", "collectors", "young", "collection_time_in_millis"))
m("logstash_jvm_gc_old_collection_count", "JVM old GC collection count", "counter", g(d, "jvm", "gc", "collectors", "old", "collection_count"))
m("logstash_jvm_gc_old_collection_time_millis", "JVM old GC collection time in milliseconds", "counter", g(d, "jvm", "gc", "collectors", "old", "collection_time_in_millis"))
m("logstash_jvm_uptime_millis", "JVM uptime in milliseconds", "gauge", g(d, "jvm", "uptime_in_millis"))

m("logstash_process_open_file_descriptors", "Number of open file descriptors", "gauge", g(d, "process", "open_file_descriptors"))
m("logstash_process_peak_open_file_descriptors", "Peak number of open file descriptors", "gauge", g(d, "process", "peak_open_file_descriptors"))
m("logstash_process_cpu_percent", "Process CPU usage percentage", "gauge", g(d, "process", "cpu", "percent"))
m("logstash_process_cpu_total_millis", "Total CPU time in milliseconds", "counter", g(d, "process", "cpu", "total_in_millis"))
m("logstash_process_virtual_memory_bytes", "Virtual memory in bytes", "gauge", g(d, "process", "mem", "total_virtual_in_bytes"))

m("logstash_queue_events", "Number of events in the queue", "gauge", g(d, "queue", "events_count"))
m("logstash_queue_size_bytes", "Queue size in bytes", "gauge", g(d, "queue", "queue_size_in_bytes"))
m("logstash_queue_max_size_bytes", "Queue max size in bytes", "gauge", g(d, "queue", "max_queue_size_in_bytes"))

m("logstash_reloads_successes", "Number of successful pipeline reloads", "counter", g(d, "reloads", "successes"))
m("logstash_reloads_failures", "Number of failed pipeline reloads", "counter", g(d, "reloads", "failures"))

for pname, p in d.get("pipelines", {}).items():
    pe = p.get("events", {})
    m("logstash_pipeline_events_in", "Pipeline events received", "counter", g(pe, "in"), {"pipeline": pname})
    m("logstash_pipeline_events_out", "Pipeline events emitted", "counter", g(pe, "out"), {"pipeline": pname})
    m("logstash_pipeline_events_filtered", "Pipeline events filtered", "counter", g(pe, "filtered"), {"pipeline": pname})
    m("logstash_pipeline_events_duration_millis", "Pipeline event processing duration in milliseconds", "counter", g(pe, "duration_in_millis"), {"pipeline": pname})
    m("logstash_pipeline_events_queue_push_duration_millis", "Pipeline queue push duration in milliseconds", "counter", g(pe, "queue_push_duration_in_millis"), {"pipeline": pname})

    pq = p.get("queue", {})
    m("logstash_pipeline_queue_events", "Pipeline queue event count", "gauge", g(pq, "events_count"), {"pipeline": pname})
    m("logstash_pipeline_queue_size_bytes", "Pipeline queue size in bytes", "gauge", g(pq, "queue_size_in_bytes"), {"pipeline": pname})
    m("logstash_pipeline_queue_max_size_bytes", "Pipeline queue max size in bytes", "gauge", g(pq, "max_queue_size_in_bytes"), {"pipeline": pname})

    pb = p.get("batch", {})
    m("logstash_pipeline_batch_event_count_current", "Pipeline batch event count (current)", "gauge", g(pb, "event_count", "current"), {"pipeline": pname})
    m("logstash_pipeline_batch_event_count_avg_lifetime", "Pipeline batch event count (lifetime average)", "gauge", g(pb, "event_count", "average", "lifetime"), {"pipeline": pname})
    m("logstash_pipeline_batch_byte_size_current", "Pipeline batch byte size (current)", "gauge", g(pb, "byte_size", "current"), {"pipeline": pname})
    m("logstash_pipeline_batch_byte_size_avg_lifetime", "Pipeline batch byte size (lifetime average)", "gauge", g(pb, "byte_size", "average", "lifetime"), {"pipeline": pname})

    pr = p.get("reloads", {})
    m("logstash_pipeline_reloads_successes", "Pipeline reload successes", "counter", g(pr, "successes"), {"pipeline": pname})
    m("logstash_pipeline_reloads_failures", "Pipeline reload failures", "counter", g(pr, "failures"), {"pipeline": pname})

    for plugin_type in ("inputs", "filters", "outputs"):
        for plugin in p.get("plugins", {}).get(plugin_type, []):
            pname_label = plugin.get("name", "unknown")
            labels = {"pipeline": pname, "type": plugin_type, "plugin": pname_label}
            pe = plugin.get("events", {})
            m("logstash_plugin_events_in", "Plugin events received", "counter", g(pe, "in"), labels)
            m("logstash_plugin_events_out", "Plugin events emitted", "counter", g(pe, "out"), labels)
            m("logstash_plugin_events_duration_millis", "Plugin event processing duration in milliseconds", "counter", g(pe, "duration_in_millis"), labels)

            fu = g(plugin, "flow", "worker_utilization", "lifetime")
            m("logstash_plugin_worker_utilization", "Plugin worker utilization (lifetime)", "gauge", fu, labels)

            if plugin_type == "filters":
                m("logstash_plugin_matches", "Grok/filter matches", "counter", g(plugin, "matches"), labels)
                m("logstash_plugin_failures", "Grok/filter failures", "counter", g(plugin, "failures"), labels)
'
