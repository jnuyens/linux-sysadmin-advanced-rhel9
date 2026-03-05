#!/bin/bash
# quick-triage.sh - Rapid system health check for RHEL 9
# Chapter 12: Troubleshooting & Problem Determination
#
# Run this script as root when called to diagnose a system issue.
# It collects key indicators to narrow down the problem area.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}=== System Quick Triage - $(date) ===${NC}\n"

# ---------- Uptime & Load ----------
echo -e "${BOLD}[1] Uptime & Load Average${NC}"
uptime
echo ""

# ---------- Failed Services ----------
echo -e "${BOLD}[2] Failed Systemd Units${NC}"
FAILED=$(systemctl --failed --no-legend 2>/dev/null | wc -l)
if [ "$FAILED" -gt 0 ]; then
    echo -e "${RED}$FAILED failed unit(s):${NC}"
    systemctl --failed --no-legend
else
    echo -e "${GREEN}No failed units${NC}"
fi
echo ""

# ---------- Recent Errors ----------
echo -e "${BOLD}[3] Recent Errors (last 30 minutes)${NC}"
ERROR_COUNT=$(journalctl -p err --since '30 min ago' --no-pager -q 2>/dev/null | wc -l)
echo "Error entries: $ERROR_COUNT"
if [ "$ERROR_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}Last 5 errors:${NC}"
    journalctl -p err --since '30 min ago' --no-pager -q -n 5 2>/dev/null
fi
echo ""

# ---------- Disk Space ----------
echo -e "${BOLD}[4] Disk Space${NC}"
FULL_FS=$(df -h --output=pcent,target -x tmpfs -x devtmpfs 2>/dev/null | tail -n +2 | awk '{gsub(/%/,"",$1); if ($1 > 85) print}')
if [ -n "$FULL_FS" ]; then
    echo -e "${RED}Filesystems above 85%:${NC}"
    df -h --output=pcent,size,used,avail,target -x tmpfs -x devtmpfs 2>/dev/null | head -1
    echo "$FULL_FS"
else
    echo -e "${GREEN}All filesystems below 85%${NC}"
fi
echo ""

# ---------- Inode Usage ----------
echo -e "${BOLD}[5] Inode Usage${NC}"
FULL_INODES=$(df -i --output=ipcent,target -x tmpfs -x devtmpfs 2>/dev/null | tail -n +2 | awk '{gsub(/%/,"",$1); if ($1 > 85) print}')
if [ -n "$FULL_INODES" ]; then
    echo -e "${RED}Inodes above 85%:${NC}"
    echo "$FULL_INODES"
else
    echo -e "${GREEN}All inode usage below 85%${NC}"
fi
echo ""

# ---------- Memory ----------
echo -e "${BOLD}[6] Memory Usage${NC}"
free -h
echo ""

# ---------- Swap ----------
echo -e "${BOLD}[7] Swap Usage${NC}"
SWAP_TOTAL=$(free -m | awk '/Swap/{print $2}')
SWAP_USED=$(free -m | awk '/Swap/{print $3}')
if [ "$SWAP_TOTAL" -gt 0 ] && [ "$SWAP_USED" -gt $((SWAP_TOTAL / 2)) ]; then
    echo -e "${RED}Swap usage is above 50% ($SWAP_USED MB / $SWAP_TOTAL MB)${NC}"
else
    echo -e "${GREEN}Swap usage normal ($SWAP_USED MB / $SWAP_TOTAL MB)${NC}"
fi
echo ""

# ---------- Top CPU Consumers ----------
echo -e "${BOLD}[8] Top 5 CPU Consumers${NC}"
ps aux --sort=-%cpu | head -6
echo ""

# ---------- Top Memory Consumers ----------
echo -e "${BOLD}[9] Top 5 Memory Consumers${NC}"
ps aux --sort=-%mem | head -6
echo ""

# ---------- Network ----------
echo -e "${BOLD}[10] Network Interfaces${NC}"
ip -br addr show 2>/dev/null || ip addr show
echo ""

# ---------- Recent OOM Kills ----------
echo -e "${BOLD}[11] OOM Killer Activity${NC}"
OOM=$(journalctl -k --since '24 hours ago' --no-pager -q 2>/dev/null | grep -c "Out of memory" || true)
if [ "$OOM" -gt 0 ]; then
    echo -e "${RED}$OOM OOM kill event(s) in last 24 hours!${NC}"
    journalctl -k --since '24 hours ago' --no-pager -q 2>/dev/null | grep "Out of memory" | tail -3
else
    echo -e "${GREEN}No OOM kills in last 24 hours${NC}"
fi
echo ""

# ---------- SELinux ----------
echo -e "${BOLD}[12] SELinux Status${NC}"
if command -v getenforce &>/dev/null; then
    STATUS=$(getenforce)
    if [ "$STATUS" = "Enforcing" ]; then
        echo -e "${GREEN}SELinux: $STATUS${NC}"
    elif [ "$STATUS" = "Permissive" ]; then
        echo -e "${YELLOW}SELinux: $STATUS (logging only, not blocking)${NC}"
    else
        echo -e "${RED}SELinux: $STATUS${NC}"
    fi
    # Check for recent denials
    DENIALS=$(journalctl -t setroubleshoot --since '1 hour ago' --no-pager -q 2>/dev/null | wc -l)
    if [ "$DENIALS" -gt 0 ]; then
        echo -e "${YELLOW}$DENIALS SELinux denial(s) in last hour${NC}"
    fi
else
    echo "SELinux tools not installed"
fi
echo ""

echo -e "${BOLD}=== Triage Complete ===${NC}"
