#!/usr/bin/env bash
# ==============================================================================
# Database Backup Script for PostgreSQL/PostGIS (Darb Platform)
# ==============================================================================

set -euo pipefail

BACKUP_DIR="/var/backups/darb"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="${BACKUP_DIR}/darb_backup_${TIMESTAMP}.sql.gz"

mkdir -p "${BACKUP_DIR}"

echo ">> Creating compressed PostgreSQL PostGIS backup: ${BACKUP_FILE}"
docker exec -t darb-db pg_dump -U darb_user -d darb_traffic | gzip > "${BACKUP_FILE}"

echo ">> Backup complete. Retaining last 7 days of backups..."
find "${BACKUP_DIR}" -type f -name "darb_backup_*.sql.gz" -mtime +7 -delete

echo ">> Done."
