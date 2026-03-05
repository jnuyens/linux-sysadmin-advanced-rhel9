#!/bin/bash
# security-audit.sh - Basic security audit for RHEL 9
# Chapter 13: Linux Security
#
# Performs a quick security posture check covering:
# accounts, permissions, services, firewall, SELinux, and updates.
# Run as root.

set -euo pipefail

BOLD='\033[1m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

REPORT_FILE="/tmp/security-audit-$(date +%Y%m%d-%H%M%S).txt"

# Log to both stdout and file
exec > >(tee "$REPORT_FILE") 2>&1

echo -e "${BOLD}=== Security Audit Report - $(hostname) - $(date) ===${NC}\n"

# ---------- User Accounts ----------
echo -e "${BOLD}[1] User Account Security${NC}"

# Users with UID 0 (should only be root)
ROOT_USERS=$(awk -F: '$3 == 0 {print $1}' /etc/passwd)
ROOT_COUNT=$(echo "$ROOT_USERS" | wc -w)
if [ "$ROOT_COUNT" -gt 1 ]; then
    echo -e "${RED}Multiple UID 0 accounts: $ROOT_USERS${NC}"
else
    echo -e "${GREEN}Only root has UID 0${NC}"
fi

# Users with empty passwords
EMPTY_PW=$(awk -F: '($2 == "" || $2 == "!!" || $2 == "!") && $1 != "root" {print $1}' /etc/shadow 2>/dev/null | head -10)
if [ -n "$EMPTY_PW" ]; then
    echo -e "${RED}Accounts with no/locked password: $EMPTY_PW${NC}"
fi

# Users with login shell that should not have one
echo "System accounts with login shells:"
awk -F: '$3 < 1000 && $7 !~ /nologin|false|sync|shutdown|halt/ && $1 != "root" {print "  "$1": "$7}' /etc/passwd

# Password aging policy
echo ""
echo "Password aging defaults (/etc/login.defs):"
grep -E "^(PASS_MAX_DAYS|PASS_MIN_DAYS|PASS_WARN_AGE)" /etc/login.defs 2>/dev/null | sed 's/^/  /'
echo ""

# ---------- SSH Security ----------
echo -e "${BOLD}[2] SSH Configuration${NC}"
SSHD_CONFIG="/etc/ssh/sshd_config"
if [ -f "$SSHD_CONFIG" ]; then
    check_ssh() {
        local param="$1"
        local expected="$2"
        local actual
        actual=$(grep -i "^${param}" "$SSHD_CONFIG" 2>/dev/null | tail -1 | awk '{print $2}')
        if [ -z "$actual" ]; then
            echo -e "  $param: ${YELLOW}not set (using default)${NC}"
        elif [ "$actual" = "$expected" ]; then
            echo -e "  $param: ${GREEN}$actual${NC}"
        else
            echo -e "  $param: ${RED}$actual (expected: $expected)${NC}"
        fi
    }
    check_ssh "PermitRootLogin" "no"
    check_ssh "PasswordAuthentication" "no"
    check_ssh "PermitEmptyPasswords" "no"
    check_ssh "X11Forwarding" "no"
    check_ssh "MaxAuthTries" "3"
    check_ssh "Protocol" "2"
else
    echo -e "${YELLOW}$SSHD_CONFIG not found${NC}"
fi
echo ""

# ---------- Firewall ----------
echo -e "${BOLD}[3] Firewall Status${NC}"
if command -v firewall-cmd &>/dev/null; then
    FW_STATE=$(firewall-cmd --state 2>/dev/null || echo "not running")
    if [ "$FW_STATE" = "running" ]; then
        echo -e "Firewalld: ${GREEN}running${NC}"
        echo "Default zone: $(firewall-cmd --get-default-zone 2>/dev/null)"
        echo "Active zones:"
        firewall-cmd --get-active-zones 2>/dev/null | sed 's/^/  /'
        echo "Allowed services:"
        firewall-cmd --list-services 2>/dev/null | sed 's/^/  /'
        echo "Open ports:"
        firewall-cmd --list-ports 2>/dev/null | sed 's/^/  /'
    else
        echo -e "Firewalld: ${RED}not running${NC}"
    fi
else
    echo -e "${YELLOW}firewall-cmd not available${NC}"
fi
echo ""

# ---------- SELinux ----------
echo -e "${BOLD}[4] SELinux Status${NC}"
if command -v getenforce &>/dev/null; then
    MODE=$(getenforce)
    if [ "$MODE" = "Enforcing" ]; then
        echo -e "SELinux: ${GREEN}$MODE${NC}"
    elif [ "$MODE" = "Permissive" ]; then
        echo -e "SELinux: ${YELLOW}$MODE (not enforcing!)${NC}"
    else
        echo -e "SELinux: ${RED}$MODE${NC}"
    fi

    # Check permissive domains
    PERM_DOMAINS=$(semanage permissive -l 2>/dev/null | grep -cE "^[a-z]" || echo "0")
    if [ "$PERM_DOMAINS" -gt 0 ]; then
        echo -e "${YELLOW}$PERM_DOMAINS domain(s) running in permissive mode${NC}"
    fi
else
    echo -e "${RED}SELinux not available${NC}"
fi
echo ""

# ---------- Filesystem Security ----------
echo -e "${BOLD}[5] Filesystem Mount Options${NC}"
echo "Checking security-relevant mount options:"
while read -r dev mount fs opts rest; do
    if [[ "$mount" =~ ^/(tmp|var/tmp|dev/shm|home)$ ]]; then
        ISSUES=""
        [[ ! "$opts" =~ nosuid ]] && ISSUES="${ISSUES} missing:nosuid"
        [[ ! "$opts" =~ nodev ]] && ISSUES="${ISSUES} missing:nodev"
        [[ "$mount" =~ ^/(tmp|var/tmp|dev/shm)$ ]] && [[ ! "$opts" =~ noexec ]] && ISSUES="${ISSUES} missing:noexec"
        if [ -n "$ISSUES" ]; then
            echo -e "  ${YELLOW}$mount ($fs):${NC}${ISSUES}"
        else
            echo -e "  ${GREEN}$mount ($fs): OK${NC}"
        fi
    fi
done < <(mount | grep -v "^proc\|^sys\|^cgroup")
echo ""

# SUID/SGID binaries
echo -e "${BOLD}[6] SUID/SGID Binaries${NC}"
SUID_COUNT=$(find / -perm -4000 -type f 2>/dev/null | wc -l)
SGID_COUNT=$(find / -perm -2000 -type f 2>/dev/null | wc -l)
echo "SUID binaries: $SUID_COUNT"
echo "SGID binaries: $SGID_COUNT"
echo "  (Review with: find / -perm -4000 -type f -ls)"
echo ""

# ---------- World-writable files ----------
echo -e "${BOLD}[7] World-Writable Directories (excluding /tmp, /var/tmp)${NC}"
WW=$(find / -type d -perm -0002 ! -path "/tmp*" ! -path "/var/tmp*" ! -path "/proc*" ! -path "/sys*" ! -path "/dev*" ! -path "/run*" 2>/dev/null | head -10)
if [ -n "$WW" ]; then
    echo -e "${YELLOW}World-writable directories found:${NC}"
    echo "$WW" | sed 's/^/  /'
else
    echo -e "${GREEN}No unexpected world-writable directories${NC}"
fi
echo ""

# ---------- Updates ----------
echo -e "${BOLD}[8] Security Updates${NC}"
if command -v dnf &>/dev/null; then
    SEC_UPDATES=$(dnf updateinfo list security 2>/dev/null | grep -c "^" || echo "0")
    echo "Available security updates: $SEC_UPDATES"
    if [ "$SEC_UPDATES" -gt 0 ]; then
        echo -e "${YELLOW}Run: dnf update --security${NC}"
    fi
else
    echo "dnf not available"
fi
echo ""

# ---------- Listening Services ----------
echo -e "${BOLD}[9] Externally Listening Services${NC}"
echo "TCP services listening on all interfaces (0.0.0.0 or ::):"
ss -tlnp 2>/dev/null | grep -E "0\.0\.0\.0:|:::" | sed 's/^/  /'
echo ""

echo -e "${BOLD}=== Audit Complete ===${NC}"
echo "Report saved to: $REPORT_FILE"
