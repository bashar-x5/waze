#!/usr/bin/env bash
# ==============================================================================
# Database Restore Script for PostgreSQL/PostGIS (Darb Platform)
# ==============================================================================

set -euo pipefail

if [ -z "${1:-}" ]; then
    echo "Usage: $0 /path/to/backup.sql.gz"
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "${BACKUP_FILE}" ]; then
    echo "Error: Backup file ${BACKUP_FILE} not found."
    exit 1
fi

echo ">> Restoring database from: ${BACKUP_FILE}"
gunzip -c "${BACKUP_FILE}" | docker exec -i darb-db psql -U darb_user -d darb_traffic

echo ">> Database restored successfully."
