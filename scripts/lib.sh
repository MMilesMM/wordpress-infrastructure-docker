#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA_DIR="${REPO_ROOT}/infrastructure"
SITES_DIR="${REPO_ROOT}/sites"
TEMPLATE_DIR="${REPO_ROOT}/site-template"
BACKUP_DIR="${REPO_ROOT}/backups"
DB_CONTAINER="wordpress-infrastructure-mariadb-1"

fatal() {
  echo "ERROR: $*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fatal "Required command not found: $1"
}

slugify() {
  local raw="$1"
  printf '%s' "$raw" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/^https?:\/\///; s/\/.*$//; s/[^a-z0-9]+/_/g; s/^_+//; s/_+$//' \
    | cut -c1-48
}

read_env_value() {
  local file="$1" key="$2"
  sed -n "s/^${key}=//p" "$file" | tail -n1
}

ensure_infra_env() {
  [[ -f "${INFRA_DIR}/.env" ]] || fatal "Missing infrastructure/.env. Run ./scripts/init.sh first."
}

ensure_infra_running() {
  docker compose --project-directory "${INFRA_DIR}" -f "${INFRA_DIR}/compose.yml" ps --status running --services | grep -qx mariadb \
    || fatal "MariaDB is not running. Run ./scripts/init.sh first."
}

root_db_password() {
  ensure_infra_env
  local pass
  pass="$(read_env_value "${INFRA_DIR}/.env" MARIADB_ROOT_PASSWORD)"
  [[ -n "$pass" ]] || fatal "MARIADB_ROOT_PASSWORD is empty."
  printf '%s' "$pass"
}

mariadb_root() {
  local pass
  pass="$(root_db_password)"
  docker compose --project-directory "${INFRA_DIR}" -f "${INFRA_DIR}/compose.yml" exec -T \
    -e MYSQL_PWD="$pass" mariadb mariadb -uroot "$@"
}

next_port() {
  local port=3000
  while :; do
    if ! grep -Rqs "^WEB_PORT=${port}$" "${SITES_DIR}"/*/.env 2>/dev/null \
      && ! ss -ltnH 2>/dev/null | awk '{print $4}' | grep -Eq "(^|:)${port}$"; then
      printf '%s' "$port"
      return
    fi
    port=$((port + 1))
  done
}

next_redis_db() {
  local db=0
  while :; do
    if ! grep -Rqs "^REDIS_DATABASE=${db}$" "${SITES_DIR}"/*/.env 2>/dev/null; then
      printf '%s' "$db"
      return
    fi
    db=$((db + 1))
    [[ "$db" -lt 256 ]] || fatal "No free Redis logical database (0-255)."
  done
}
