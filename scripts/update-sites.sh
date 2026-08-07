#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

shopt -s nullglob
for env_file in "${SITES_DIR}"/*/.env; do
  dir="$(dirname "$env_file")"
  domain="$(read_env_value "$env_file" SITE_DOMAIN)"
  echo "Updating ${domain}..."
  docker compose --project-directory "$dir" -f "$dir/compose.yml" pull wordpress
  docker compose --project-directory "$dir" -f "$dir/compose.yml" up -d
  docker image prune -f >/dev/null
done
