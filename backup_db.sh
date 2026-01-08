#!/bin/bash
BACKUP_DIR="/home/veilapp/backups"
DB_PATH="/home/veilapp/data/veil.db"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/veil_$TIMESTAMP.db"

mkdir -p "$BACKUP_DIR"

# 1. Hot backup
sqlite3 "$DB_PATH" ".backup $BACKUP_FILE"

# 2. Compress
gzip "$BACKUP_FILE"
GZ_FILE="$BACKUP_FILE.gz"

# 3. Upload to R2 (Requires R2 bucket named "veil-backups")
rclone copy "$GZ_FILE" r2:veil-backups --s3-no-check-bucket

# 4. Cleanup old files (local only)
find "$BACKUP_DIR" -type f -name "*.gz" -mtime +7 -delete

echo "Backup success: $GZ_FILE uploaded to R2."
