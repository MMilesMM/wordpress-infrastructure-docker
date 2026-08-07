#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

printf '%-35s %-8s %-8s %-24s %s\n' "DOMAIN" "PORT" "REDIS" "DATABASE" "STATE"
printf '%-35s %-8s %-8s %-24s %s\n' "-----------------------------------" "--------" "--------" "------------------------" "-----"

shopt -s nullglob
for env_file in "${SITES_DIR}"/*/.env; do
  dir="$(dirname "$env_file")"
  domain="$(read_env_value "$env_file" SITE_DOMAIN)"
  port="$(read_env_value "$env_file" WEB_PORT)"
  redis_db="$(read_env_value "$env_file" REDIS_DATABASE)"
  db="$(read_env_value "$env_file" DB_NAME)"
  state="$(docker compose --project-directory "$dir" -f "$dir/compose.yml" ps --status running --services 2>/dev/null | grep -qx wordpress && echo running || echo stopped)"
  printf '%-35s %-8s %-8s %-24s %s\n' "$domain" "$port" "$redis_db" "$db" "$state"
done
