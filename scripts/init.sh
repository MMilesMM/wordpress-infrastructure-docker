#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

need_cmd docker
need_cmd openssl

if [[ ! -f "${INFRA_DIR}/.env" ]]; then
  root_password="$(openssl rand -hex 32)"
  cat > "${INFRA_DIR}/.env" <<ENV
MARIADB_ROOT_PASSWORD=${root_password}
MARIADB_INNODB_BUFFER_POOL_SIZE=256M
ENV
  chmod 600 "${INFRA_DIR}/.env"
  echo "Created infrastructure/.env with a random MariaDB root password."
else
  echo "infrastructure/.env already exists; keeping it unchanged."
fi

echo "Starting shared MariaDB and Redis..."
docker compose --project-directory "${INFRA_DIR}" -f "${INFRA_DIR}/compose.yml" up -d

echo "Infrastructure is ready."
echo "Create your first site with: ./scripts/create-site.sh example.de"
