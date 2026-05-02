#!/bin/bash
# =============================================================================
# Automation Service — Automated PostgreSQL Backup Script
# =============================================================================
# Usage:    bash backup.sh
# Schedule: Add to cron for daily backups at 2:00 AM:
#           0 2 * * * /path/to/chatwoot/deployment/scripts/backup.sh >> /var/log/chatwoot_backup.log 2>&1
# =============================================================================

set -euo pipefail

# --- Configuration ---
BACKUP_DIR="/var/backups/automation-service"
DB_CONTAINER="chatwoot-postgres-1"        # docker container name (check with: docker ps)
DB_NAME="${POSTGRES_DB:-chatwoot}"
DB_USER="${POSTGRES_USER:-postgres}"
RETAIN_DAYS=7                              # Keep backups for N days
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/postgres_${TIMESTAMP}.sql.gz"
LOG_PREFIX="[AutomationService Backup]"

# --- Create backup directory if it doesn't exist ---
mkdir -p "$BACKUP_DIR"

echo "$LOG_PREFIX Starting backup at $(date)"
echo "$LOG_PREFIX Database: $DB_NAME | Container: $DB_CONTAINER"

# --- Perform the backup ---
if docker exec "$DB_CONTAINER" pg_dump -U "$DB_USER" "$DB_NAME" | gzip > "$BACKUP_FILE"; then
    SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
    echo "$LOG_PREFIX ✅ Backup successful: $BACKUP_FILE ($SIZE)"
else
    echo "$LOG_PREFIX ❌ Backup FAILED! Check container name and database credentials."
    exit 1
fi

# --- Remove backups older than RETAIN_DAYS ---
echo "$LOG_PREFIX Cleaning up backups older than $RETAIN_DAYS days..."
DELETED=$(find "$BACKUP_DIR" -name "postgres_*.sql.gz" -mtime +$RETAIN_DAYS -print -delete | wc -l)
echo "$LOG_PREFIX Deleted $DELETED old backup(s)."

# --- List current backups ---
echo "$LOG_PREFIX Current backups in $BACKUP_DIR:"
ls -lh "$BACKUP_DIR"/*.sql.gz 2>/dev/null || echo "$LOG_PREFIX  (no backups found)"

echo "$LOG_PREFIX Backup complete at $(date)"

# =============================================================================
# RESTORE INSTRUCTIONS:
#   To restore a backup, run:
#     gunzip -c /var/backups/automation-service/postgres_TIMESTAMP.sql.gz | \
#     docker exec -i chatwoot-postgres-1 psql -U postgres -d chatwoot
# =============================================================================
