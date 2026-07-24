#!/usr/bin/env bash

echo "# HELP node_user_authorized_keys Whether a user home directory has authorized_keys (1 = yes, 0 = no)"
echo "# TYPE node_user_authorized_keys gauge"
echo "# HELP node_user_authorized_keys_count Total number of home directories with authorized_keys"
echo "# TYPE node_user_authorized_keys_count gauge"
echo "# HELP node_user_authorized_keys_total Total number of SSH keys across all users"
echo "# TYPE node_user_authorized_keys_total gauge"

total_dirs=0
total_keys=0

while IFS=: read -r user _ uid _ _ home _; do
  [ "$uid" -lt 1000 ] && [ "$uid" -ne 0 ] && continue
  [ ! -d "$home" ] && continue

  ak_file="${home}/.ssh/authorized_keys"
  if sudo /usr/bin/test -f "$ak_file" 2>/dev/null; then
    keys=$(sudo /usr/bin/grep -cv '^\s*#\|^\s*$' "$ak_file" 2>/dev/null || echo 0)
    echo "node_user_authorized_keys{user=\"${user}\",home=\"${home}\"} 1"
    echo "node_user_authorized_keys_keys{user=\"${user}\",home=\"${home}\"} ${keys}"
    total_dirs=$((total_dirs + 1))
    total_keys=$((total_keys + keys))
  else
    echo "node_user_authorized_keys{user=\"${user}\",home=\"${home}\"} 0"
  fi
done < /etc/passwd

echo "node_user_authorized_keys_count ${total_dirs}"
echo "node_user_authorized_keys_total ${total_keys}"
