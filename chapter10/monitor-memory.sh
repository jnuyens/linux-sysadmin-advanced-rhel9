#!/bin/bash
# Memory Monitoring Script - Chapter 10 Exercise
#
# Monitors key memory metrics and alerts on thresholds.
# Designed for cron or systemd timer execution.
#
# Usage:
#     bash monitor-memory.sh              # single check
#     watch -n 5 bash monitor-memory.sh   # continuous monitoring
#
# Thresholds can be customized below.

set -euo pipefail

# ---------------------------------------------------------------
# Configuration - adjust these thresholds
# ---------------------------------------------------------------
AVAIL_WARN_PCT=15      # warn if available < 15% of total
SWAP_WARN_MB=100       # warn if swap used > 100 MB
DIRTY_WARN_MB=2048     # warn if dirty pages > 2 GB
PSI_MEM_WARN=25.0      # warn if memory PSI avg10 > 25%

# ---------------------------------------------------------------
# Gather metrics from /proc/meminfo (in kB)
# ---------------------------------------------------------------
eval "$(awk '
    /^MemTotal:/     { printf "MEM_TOTAL=%d\n", $2 }
    /^MemAvailable:/ { printf "MEM_AVAIL=%d\n", $2 }
    /^SwapTotal:/    { printf "SWAP_TOTAL=%d\n", $2 }
    /^SwapFree:/     { printf "SWAP_FREE=%d\n", $2 }
    /^Dirty:/        { printf "DIRTY=%d\n", $2 }
' /proc/meminfo)"

SWAP_USED=$(( (SWAP_TOTAL - SWAP_FREE) / 1024 ))
AVAIL_PCT=$(( MEM_AVAIL * 100 / MEM_TOTAL ))
DIRTY_MB=$(( DIRTY / 1024 ))

# ---------------------------------------------------------------
# PSI (Pressure Stall Information)
# ---------------------------------------------------------------
PSI_MEM="n/a"
if [ -f /proc/pressure/memory ]; then
    PSI_MEM=$(awk '/^some/ { for(i=1;i<=NF;i++) if ($i ~ /^avg10=/) print substr($i,7) }' /proc/pressure/memory)
fi

PSI_IO="n/a"
if [ -f /proc/pressure/io ]; then
    PSI_IO=$(awk '/^some/ { for(i=1;i<=NF;i++) if ($i ~ /^avg10=/) print substr($i,7) }' /proc/pressure/io)
fi

# ---------------------------------------------------------------
# Output
# ---------------------------------------------------------------
echo "=== Memory Status $(date '+%Y-%m-%d %H:%M:%S') ==="
printf "  Available:    %d MB / %d MB (%d%%)\n" $((MEM_AVAIL/1024)) $((MEM_TOTAL/1024)) "$AVAIL_PCT"
printf "  Swap used:    %d MB\n" "$SWAP_USED"
printf "  Dirty pages:  %d MB\n" "$DIRTY_MB"
printf "  PSI memory:   %s%%  (avg10)\n" "$PSI_MEM"
printf "  PSI I/O:      %s%%  (avg10)\n" "$PSI_IO"

# ---------------------------------------------------------------
# Alerts
# ---------------------------------------------------------------
ALERTS=0

if [ "$AVAIL_PCT" -lt "$AVAIL_WARN_PCT" ]; then
    echo "  WARNING: Available memory is ${AVAIL_PCT}% (threshold: ${AVAIL_WARN_PCT}%)"
    ALERTS=$((ALERTS + 1))
fi

if [ "$SWAP_USED" -gt "$SWAP_WARN_MB" ]; then
    echo "  WARNING: Swap usage is ${SWAP_USED} MB (threshold: ${SWAP_WARN_MB} MB)"
    ALERTS=$((ALERTS + 1))
fi

if [ "$DIRTY_MB" -gt "$DIRTY_WARN_MB" ]; then
    echo "  WARNING: Dirty pages at ${DIRTY_MB} MB (threshold: ${DIRTY_WARN_MB} MB)"
    ALERTS=$((ALERTS + 1))
fi

if [ "$PSI_MEM" != "n/a" ]; then
    PSI_INT=${PSI_MEM%%.*}
    if [ "$PSI_INT" -gt "${PSI_MEM_WARN%%.*}" ]; then
        echo "  WARNING: Memory pressure PSI avg10=${PSI_MEM}% (threshold: ${PSI_MEM_WARN}%)"
        ALERTS=$((ALERTS + 1))
    fi
fi

if [ "$ALERTS" -eq 0 ]; then
    echo "  Status: OK"
fi

exit "$ALERTS"
