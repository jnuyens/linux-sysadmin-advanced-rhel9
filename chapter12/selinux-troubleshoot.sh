#!/bin/bash
# selinux-troubleshoot.sh - SELinux troubleshooting helper
# Chapter 12: Troubleshooting & Problem Determination
#
# Checks SELinux status, recent denials, and suggests fixes.
# Run as root.

set -euo pipefail

BOLD='\033[1m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${BOLD}=== SELinux Troubleshooting ===${NC}\n"

# ---------- Status ----------
echo -e "${BOLD}[1] SELinux Status${NC}"
if command -v getenforce &>/dev/null; then
    MODE=$(getenforce)
    POLICY=$(sestatus 2>/dev/null | grep "Loaded policy" | awk '{print $NF}')
    CONFIG_MODE=$(sestatus 2>/dev/null | grep "Mode from config" | awk '{print $NF}')

    echo "Current mode:    $MODE"
    echo "Config mode:     ${CONFIG_MODE:-unknown}"
    echo "Policy:          ${POLICY:-unknown}"

    if [ "$MODE" = "Disabled" ]; then
        echo -e "\n${RED}SELinux is disabled. Enable in /etc/selinux/config and reboot.${NC}"
        echo "After enabling, a full filesystem relabel is needed (touch /.autorelabel)"
        exit 0
    fi
else
    echo -e "${RED}SELinux tools not installed (install policycoreutils)${NC}"
    exit 1
fi
echo ""

# ---------- Permissive Domains ----------
echo -e "${BOLD}[2] Permissive Domains${NC}"
PERMISSIVE=$(semanage permissive -l 2>/dev/null | grep -v "^Builtin" | grep -v "^$" | grep -v "^Customized" || true)
if [ -n "$PERMISSIVE" ]; then
    echo -e "${YELLOW}Domains running in permissive mode:${NC}"
    echo "$PERMISSIVE"
else
    echo -e "${GREEN}No domains in permissive mode (all enforcing)${NC}"
fi
echo ""

# ---------- Recent Denials ----------
echo -e "${BOLD}[3] Recent SELinux Denials (last 2 hours)${NC}"
DENIALS=$(ausearch -m AVC -ts recent 2>/dev/null | grep -c "^type=AVC" || echo "0")
echo "Denial count: $DENIALS"

if [ "$DENIALS" -gt 0 ]; then
    echo -e "\n${YELLOW}Last 5 denials:${NC}"
    ausearch -m AVC -ts recent 2>/dev/null | grep "^type=AVC" | tail -5 | while read -r line; do
        # Extract key fields
        SCON=$(echo "$line" | grep -oP 'scontext=\K\S+' || true)
        TCON=$(echo "$line" | grep -oP 'tcontext=\K\S+' || true)
        TCLASS=$(echo "$line" | grep -oP 'tclass=\K\S+' || true)
        PERM=$(echo "$line" | grep -oP '\{ \K[^}]+' || true)
        echo "  Action: $PERM | Class: $TCLASS"
        echo "  Source: $SCON"
        echo "  Target: $TCON"
        echo ""
    done

    echo -e "${BOLD}Suggested fixes:${NC}"
    echo ""
    echo "Option 1: Check if setroubleshoot has suggestions:"
    echo "  sealert -a /var/log/audit/audit.log | head -50"
    echo ""
    echo "Option 2: Generate and apply a custom policy module:"
    echo "  ausearch -m AVC -ts recent | audit2allow -M mypolicy"
    echo "  semodule -i mypolicy.pp"
    echo ""
    echo "Option 3: Fix file contexts (most common fix):"
    echo "  restorecon -Rv /path/to/affected/files"
    echo ""
    echo "Option 4: Set boolean if it is a known toggle:"
    echo "  getsebool -a | grep <keyword>"
    echo "  setsebool -P <boolean> on"
    echo ""
    echo "Option 5: Set domain to permissive (selective, not system-wide):"
    echo "  semanage permissive -a <domain_t>"
    echo "  # Example: semanage permissive -a httpd_t"
else
    echo -e "${GREEN}No recent SELinux denials${NC}"
fi
echo ""

# ---------- File Context Issues ----------
echo -e "${BOLD}[4] Common File Context Checks${NC}"
DIRS_TO_CHECK=("/var/www" "/srv" "/opt" "/home")
for dir in "${DIRS_TO_CHECK[@]}"; do
    if [ -d "$dir" ]; then
        MISMATCHES=$(restorecon -Rnv "$dir" 2>/dev/null | head -5)
        if [ -n "$MISMATCHES" ]; then
            echo -e "${YELLOW}Context mismatches in $dir:${NC}"
            echo "$MISMATCHES"
            echo "  Fix: restorecon -Rv $dir"
            echo ""
        fi
    fi
done
echo ""

# ---------- Boolean Status ----------
echo -e "${BOLD}[5] Commonly Toggled Booleans${NC}"
BOOLEANS=(
    "httpd_can_network_connect"
    "httpd_can_network_connect_db"
    "httpd_enable_homedirs"
    "samba_enable_home_dirs"
    "ftpd_full_access"
    "nis_enabled"
)
for bool in "${BOOLEANS[@]}"; do
    VAL=$(getsebool "$bool" 2>/dev/null | awk '{print $NF}' || echo "N/A")
    if [ "$VAL" = "on" ]; then
        echo -e "  $bool: ${GREEN}$VAL${NC}"
    elif [ "$VAL" = "off" ]; then
        echo "  $bool: $VAL"
    fi
done
echo ""

echo -e "${BOLD}=== SELinux Troubleshooting Complete ===${NC}"
