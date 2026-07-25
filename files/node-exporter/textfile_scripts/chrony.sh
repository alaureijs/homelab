#!/usr/bin/env bash
set -euo pipefail

TRACKING=$(sudo /usr/bin/chronyc -c tracking 2>/dev/null) || exit 0

IFS=',' read -r ref_id ref_host stratum _ _ offset _ root_dispersion _ _ _ _ _ _ <<< "$TRACKING"

cat <<EOF
# HELP chrony_tracking_reference_info The stratum of the current preferred source
# TYPE chrony_tracking_reference_info gauge
chrony_tracking_reference_info{ref_id="${ref_id}",ref_host="${ref_host}"} 1
# HELP chrony_tracking_stratum The stratum of the current preferred source
# TYPE chrony_tracking_stratum gauge
chrony_tracking_stratum ${stratum}
# HELP chrony_tracking_system_offset_seconds The current estimated drift of system time from true time
# TYPE chrony_tracking_system_offset_seconds gauge
chrony_tracking_system_offset_seconds ${offset}
# HELP chrony_tracking_root_dispersion_seconds The absolute bound on the computer's clock accuracy
# TYPE chrony_tracking_root_dispersion_seconds gauge
chrony_tracking_root_dispersion_seconds ${root_dispersion}
EOF
