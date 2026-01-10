#!/bin/bash

# Configuration
BACKUP_ROOT="/root/backups"
DEV_DB="/root/veil_data_dev/veil.db"
PROD_DB="/root/veil_data_prod/veil.db"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create backup directories
mkdir -p "$BACKUP_ROOT/dev"
mkdir -p "$BACKUP_ROOT/prod"

# --- Backup Function ---
backup_db() {
    local source_path=$1
    local target_dir=$2
    local label=$3
    local backup_file="$target_dir/${label}_$TIMESTAMP.db"

    if [ -f "$source_path" ]; then
        echo "Starting backup for $label..."
        # Use sqlite3 for hot backup (safe while server is running)
        sqlite3 "$source_path" ".backup $backup_file"
        
        # Compress
        gzip "$backup_file"
        local gz_file="$backup_file.gz"
        
        echo "Backup created: $gz_file"
        
        # Optional: Upload to S3/R2 if rclone is configured
        if command -v rclone &> /dev/null; then
             echo "Uploading $label to R2..."
             rclone copy "$gz_file" r2:veil-backups/$label --s3-no-check-bucket
        fi

        # Cleanup local files older than 7 days
        find "$target_dir" -type f -name "*.gz" -mtime +7 -delete
    else
        echo "Error: Source DB not found at $source_path"
    fi
}

# --- Execute Backups ---
backup_db "$DEV_DB" "$BACKUP_ROOT/dev" "dev"
backup_db "$PROD_DB" "$BACKUP_ROOT/prod" "prod"

echo "All backups processed at $(date)"
