#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

need_cmd tar
need_cmd gzip

[[ $# -eq 1 ]] || fatal "Usage: $0 <domain>"
DOMAIN="$1"
SITE_DIR="${SITES_DIR}/${DOMAIN}"
ENV_FILE="${SITE_DIR}/.env"
[[ -f "$ENV_FILE" ]] || fatal "Site not found: ${DOMAIN}"

ensure_infra_running
DB_NAME="$(read_env_value "$ENV_FILE" DB_NAME)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
TARGET="${BACKUP_DIR}/${DOMAIN}/${TIMESTAMP}"
mkdir -p "$TARGET"

mariadb_root --single-transaction --quick --routines --triggers "$DB_NAME" | gzip -9 > "$TARGET/database.sql.gz"
tar -C "$SITE_DIR" -czf "$TARGET/wordpress_data.tar.gz" wordpress_data
cp "$ENV_FILE" "$TARGET/site.env"
chmod 600 "$TARGET/site.env"

cat > "$TARGET/README.txt" <<INFO
Backup of ${DOMAIN}
Created: $(date --iso-8601=seconds 2>/dev/null || date)
Database: ${DB_NAME}
Restore files manually or use this backup as disaster-recovery input.
The site.env file contains credentials and must be protected.
INFO

echo "Backup created: $TARGET"
