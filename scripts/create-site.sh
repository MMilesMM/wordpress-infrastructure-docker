#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

need_cmd docker
need_cmd openssl
need_cmd sed
need_cmd grep

[[ $# -ge 1 && $# -le 2 ]] || fatal "Usage: $0 <domain> [host-port]"

DOMAIN="$1"
[[ "$DOMAIN" =~ ^[A-Za-z0-9.-]+$ ]] || fatal "Domain may contain only letters, numbers, dots, and hyphens."
SLUG="$(slugify "$DOMAIN")"
[[ -n "$SLUG" ]] || fatal "Could not derive a valid site slug from: $DOMAIN"

SITE_DIR="${SITES_DIR}/${DOMAIN}"
[[ ! -e "$SITE_DIR" ]] || fatal "Site already exists: ${SITE_DIR}"

ensure_infra_running

WEB_PORT="${2:-$(next_port)}"
[[ "$WEB_PORT" =~ ^[0-9]+$ ]] || fatal "Port must be numeric."
(( WEB_PORT >= 1024 && WEB_PORT <= 65535 )) || fatal "Port must be between 1024 and 65535."

if grep -Rqs "^WEB_PORT=${WEB_PORT}$" "${SITES_DIR}"/*/.env 2>/dev/null; then
  fatal "Port ${WEB_PORT} is already assigned to another managed site."
fi

REDIS_DATABASE="$(next_redis_db)"
DB_NAME="wp_${SLUG}"
DB_USER="wp_${SLUG}"
DB_PASSWORD="$(openssl rand -hex 24)"

# Database and user names are generated only from [a-z0-9_], so quoting is safe.
if mariadb_root -Nse "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='${DB_NAME}'" | grep -qx "$DB_NAME"; then
  fatal "Database ${DB_NAME} already exists. Refusing to overwrite it."
fi

mkdir -p "$SITE_DIR/wordpress_data"
cp "${TEMPLATE_DIR}/compose.yml" "$SITE_DIR/compose.yml"

cat > "$SITE_DIR/.env" <<ENV
SITE_DOMAIN=${DOMAIN}
SITE_SLUG=${SLUG}
WEB_PORT=${WEB_PORT}
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
REDIS_DATABASE=${REDIS_DATABASE}
WORDPRESS_IMAGE=mmilesmm/wordpress-apache-php-fix:latest
ENV
chmod 600 "$SITE_DIR/.env"

rollback() {
  echo "Creation failed. Cleaning up site container, directory, and database objects..." >&2
  docker compose --project-directory "$SITE_DIR" -f "$SITE_DIR/compose.yml" down >/dev/null 2>&1 || true
  mariadb_root -e "DROP DATABASE IF EXISTS \`${DB_NAME}\`; DROP USER IF EXISTS '${DB_USER}'@'%'; FLUSH PRIVILEGES;" >/dev/null 2>&1 || true
  rm -rf "$SITE_DIR"
}
trap rollback ERR

mariadb_root <<SQL
CREATE DATABASE \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
SQL

docker compose --project-directory "$SITE_DIR" -f "$SITE_DIR/compose.yml" up -d
trap - ERR

cat <<INFO

Site created successfully.
  Domain:         ${DOMAIN}
  Local URL:      http://127.0.0.1:${WEB_PORT}
  Directory:      ${SITE_DIR}
  Database:       ${DB_NAME}
  Redis database: ${REDIS_DATABASE}

Point your reverse proxy to 127.0.0.1:${WEB_PORT}.
INFO
