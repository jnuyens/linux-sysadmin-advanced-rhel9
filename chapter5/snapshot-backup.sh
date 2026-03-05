#!/bin/bash
# LVM Snapshot Backup Script
# Chapter 5 - Advanced Linux Sysadmin Course
#
# Usage: sudo bash snapshot-backup.sh /dev/vgname/lvname /path/to/backup/dir
#
# This script demonstrates the LVM snapshot backup workflow:
# 1. Create a snapshot of the specified logical volume
# 2. Mount it read-only
# 3. Create a compressed backup
# 4. Clean up the snapshot
#
# The advantage: the original LV stays online and writable
# during the entire backup process. Downtime is only the
# brief moment of snapshot creation (milliseconds).

set -euo pipefail

# ---- Configuration ----
SNAP_SIZE="1G"              # Size of COW space for snapshot
SNAP_NAME="backup-snap"     # Name for the temporary snapshot
MOUNT_POINT="/mnt/backup-snapshot"

# ---- Input validation ----
if [ $# -ne 2 ]; then
    echo "Usage: $0 <logical-volume-path> <backup-directory>"
    echo "Example: $0 /dev/datavg/data /tmp/backups"
    exit 1
fi

LV_PATH="$1"
BACKUP_DIR="$2"

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root (sudo)"
    exit 1
fi

if ! lvs "$LV_PATH" &>/dev/null; then
    echo "Error: Logical volume $LV_PATH does not exist"
    exit 1
fi

# Extract VG name from LV path
VG_NAME=$(lvs --noheadings -o vg_name "$LV_PATH" | tr -d ' ')
LV_NAME=$(lvs --noheadings -o lv_name "$LV_PATH" | tr -d ' ')

mkdir -p "$BACKUP_DIR"
mkdir -p "$MOUNT_POINT"

# ---- Cleanup function ----
cleanup() {
    echo "[cleanup] Unmounting snapshot..."
    umount "$MOUNT_POINT" 2>/dev/null || true
    echo "[cleanup] Removing snapshot..."
    lvremove -f "/dev/$VG_NAME/$SNAP_NAME" 2>/dev/null || true
    rmdir "$MOUNT_POINT" 2>/dev/null || true
}
trap cleanup EXIT

# ---- Step 1: Create snapshot ----
echo "============================================"
echo "LVM Snapshot Backup"
echo "============================================"
echo ""
echo "Source LV:    $LV_PATH"
echo "Backup dir:   $BACKUP_DIR"
echo "Snapshot size: $SNAP_SIZE (COW space)"
echo ""

echo "[1/4] Creating snapshot (this is instant - COW)..."
START_TIME=$(date +%s)

lvcreate -s -n "$SNAP_NAME" -L "$SNAP_SIZE" "$LV_PATH"

SNAP_TIME=$(date +%s)
echo "      Snapshot created in $((SNAP_TIME - START_TIME)) second(s)"
echo "      Any service using $LV_PATH can continue running!"
echo ""

# ---- Step 2: Mount snapshot read-only ----
echo "[2/4] Mounting snapshot read-only at $MOUNT_POINT..."
mount -o ro "/dev/$VG_NAME/$SNAP_NAME" "$MOUNT_POINT"
echo ""

# ---- Step 3: Create backup ----
BACKUP_FILE="$BACKUP_DIR/${LV_NAME}-backup-$(date +%F-%H%M%S).tar.gz"
echo "[3/4] Creating backup: $BACKUP_FILE"
echo "      This may take a while for large volumes..."
tar czf "$BACKUP_FILE" -C "$MOUNT_POINT" .
BACKUP_SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
echo "      Backup complete: $BACKUP_SIZE"
echo ""

# ---- Step 4: Verify snapshot health ----
echo "[4/4] Snapshot COW usage:"
lvs "/dev/$VG_NAME/$SNAP_NAME" -o lv_name,origin,data_percent,lv_size
echo ""

# Cleanup happens via trap
echo "============================================"
echo "Backup complete!"
echo "  File: $BACKUP_FILE"
echo "  Size: $BACKUP_SIZE"
END_TIME=$(date +%s)
echo "  Total time: $((END_TIME - START_TIME)) seconds"
echo "============================================"
