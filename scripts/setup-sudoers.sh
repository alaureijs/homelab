#!/usr/bin/env bash
set -euo pipefail

USER="${1:-$(whoami)}"
SUDOERS_FILE="/etc/sudoers.d/ansible-nopasswd"

if [ "$(id -u)" -ne 0 ]; then
  echo "Error: Run as root — sudo ./scripts/setup-sudoers.sh [username]"
  exit 1
fi

echo "Allowing passwordless sudo for '${USER}'..."
echo "${USER} ALL=(ALL) NOPASSWD: ALL" > "${SUDOERS_FILE}"
chmod 440 "${SUDOERS_FILE}"

echo "Done. Verify with: sudo -l -U ${USER}"
