#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

[[ $# -ge 1 && $# -le 2 ]] || fatal "Usage: $0 <domain> [--keep-data]"
DOMAIN="$1"
MODE="${2:-}"
SITE_DIR="${SITES_DIR}/${DOMAIN}"
ENV_FILE="${SITE_DIR}/.env"

[[ -f "$ENV_FILE" ]] || fatal "Site not found: ${DOMAIN}"

DB_NAME="$(read_env_value "$ENV_FILE" DB_NAME)"
DB_USER="$(read_env_value "$ENV_FILE" DB_USER)"
REDIS_DATABASE="$(read_env_value "$ENV_FILE" REDIS_DATABASE)"

docker compose --project-directory "$SITE_DIR" -f "$SITE_DIR/compose.yml" down

if [[ "$MODE" == "--keep-data" ]]; then
  echo "Containers removed. Site files and database kept."
  exit 0
fi

ensure_infra_running
mariadb_root -e "DROP DATABASE IF EXISTS \`${DB_NAME}\`; DROP USER IF EXISTS '${DB_USER}'@'%'; FLUSH PRIVILEGES;"
docker compose --project-directory "${INFRA_DIR}" -f "${INFRA_DIR}/compose.yml" exec -T redis redis-cli -n "$REDIS_DATABASE" FLUSHDB >/dev/null
rm -rf "$SITE_DIR"

echo "Removed ${DOMAIN}, its database, Redis cache, and WordPress files."
