#!/bin/bash
# Automated Backup Script - Chapter 7 Exercise
# Usage: sudo bash automated-backup.sh
#
# This script demonstrates a complete backup workflow using rsync
# with --link-dest for space-efficient incremental backups.
# Each backup looks like a full copy but unchanged files are hard-linked,
# using almost no extra disk space.
#
# Designed to be called by backup.service / backup.timer

set -euo pipefail

# ---- Configuration ----
SOURCE="/data/"                    # Note trailing slash: sync CONTENTS
BACKUP_BASE="/backup"
LATEST_LINK="$BACKUP_BASE/latest"
DATE_DIR="$BACKUP_BASE/$(date +%F-%H%M%S)"
LOG_FILE="/var/log/backup.log"

# ---- Functions ----
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

# ---- Pre-flight checks ----
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root (sudo)"
    exit 1
fi

if [ ! -d "$SOURCE" ]; then
    log "ERROR: Source directory $SOURCE does not exist"
    exit 1
fi

mkdir -p "$BACKUP_BASE"

# ---- Run backup ----
log "Starting backup of $SOURCE to $DATE_DIR"

# Build rsync command
RSYNC_OPTS="-av --delete"

# Use --link-dest if a previous backup exists
if [ -L "$LATEST_LINK" ]; then
    RSYNC_OPTS="$RSYNC_OPTS --link-dest=$LATEST_LINK"
    log "Using link-dest from previous backup: $(readlink -f "$LATEST_LINK")"
else
    log "No previous backup found - performing full backup"
fi

# Execute rsync
# Note: source has trailing slash = copy CONTENTS of /data/
# Without trailing slash, it would create /backup/DATE/data/
rsync $RSYNC_OPTS "$SOURCE" "$DATE_DIR/" 2>&1 | tee -a "$LOG_FILE"

# ---- Update latest symlink ----
ln -snf "$DATE_DIR" "$LATEST_LINK"
log "Updated latest symlink to $DATE_DIR"

# ---- Report ----
BACKUP_SIZE=$(du -sh "$DATE_DIR" | cut -f1)
ACTUAL_SIZE=$(du -sh --apparent-size "$DATE_DIR" | cut -f1)
log "Backup complete: $DATE_DIR"
log "Apparent size: $ACTUAL_SIZE (actual disk usage: $BACKUP_SIZE)"

# ---- Optional: remove backups older than 30 days ----
# Uncomment to enable automatic cleanup
# find "$BACKUP_BASE" -maxdepth 1 -type d -name "20*" -mtime +30 -exec rm -rf {} \;
# log "Cleaned up backups older than 30 days"

log "Done"
