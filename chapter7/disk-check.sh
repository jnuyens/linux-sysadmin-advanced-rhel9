#!/bin/bash
# Disk Space Check Script - Chapter 7 Exercise
# Usage: sudo bash disk-check.sh
#
# Called by disk-check.service / disk-check.timer
# Checks all mounted filesystems and warns if usage exceeds threshold.
# Output goes to journal via StandardOutput=journal in the service unit.

set -euo pipefail

WARN_THRESHOLD=80    # Warn at 80% usage
CRIT_THRESHOLD=95    # Critical at 95% usage

echo "=== Disk Space Check: $(date) ==="

WARNINGS=0

# Check each mounted filesystem (skip tmpfs, devtmpfs, etc.)
while IFS= read -r line; do
    USAGE=$(echo "$line" | awk '{print $5}' | tr -d '%')
    MOUNT=$(echo "$line" | awk '{print $6}')
    DEVICE=$(echo "$line" | awk '{print $1}')

    if [ "$USAGE" -ge "$CRIT_THRESHOLD" ]; then
        echo "CRITICAL: $MOUNT ($DEVICE) is ${USAGE}% full!"
        WARNINGS=$((WARNINGS + 1))
    elif [ "$USAGE" -ge "$WARN_THRESHOLD" ]; then
        echo "WARNING: $MOUNT ($DEVICE) is ${USAGE}% full"
        WARNINGS=$((WARNINGS + 1))
    else
        echo "OK: $MOUNT ($DEVICE) is ${USAGE}% full"
    fi
done < <(df -h --output=source,size,used,avail,pcent,target -x tmpfs -x devtmpfs -x squashfs | tail -n +2)

echo ""
if [ "$WARNINGS" -gt 0 ]; then
    echo "Found $WARNINGS filesystem(s) above ${WARN_THRESHOLD}% threshold"
    exit 1
else
    echo "All filesystems OK (below ${WARN_THRESHOLD}%)"
    exit 0
fi
