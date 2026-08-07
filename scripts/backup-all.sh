#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

shopt -s nullglob
sites=("${SITES_DIR}"/*/.env)

if (( ${#sites[@]} == 0 )); then
  echo "No sites found."
  exit 0
fi

for env_file in "${sites[@]}"; do
  domain="$(read_env_value "$env_file" SITE_DOMAIN)"
  echo "Backing up ${domain}..."
  "${REPO_ROOT}/scripts/backup-site.sh" "$domain"
done
