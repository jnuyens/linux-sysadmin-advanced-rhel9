#!/bin/bash
# User Audit Script - Chapter 9 Exercise
# Usage: sudo bash audit-users.sh
#
# Generates a quick security audit report covering:
# - Users with UID 0 (should only be root)
# - Accounts with empty passwords
# - SUID/SGID binaries
# - Users who logged in recently
# - Failed login attempts

set -euo pipefail

echo "========================================"
echo "  User Security Audit Report"
echo "  $(date)"
echo "========================================"
echo ""

# Check for UID 0 accounts (should only be root)
echo "--- Accounts with UID 0 (root equivalent) ---"
awk -F: '$3 == 0 {print $1}' /etc/passwd
echo ""

# Check for accounts with no password
echo "--- Accounts with empty password field ---"
if sudo awk -F: '($2 == "" || $2 == "!") {print $1 " - " $2}' /etc/shadow 2>/dev/null; then
    echo "(none is good)"
fi
echo ""

# Check for accounts with no expiry on passwords
echo "--- Active users with no password expiry (max=99999) ---"
sudo awk -F: '$5 == 99999 && $3 >= 1000 && $7 != "/sbin/nologin" && $7 != "/bin/false" {print $1}' /etc/passwd | while read user; do
    MAX=$(sudo chage -l "$user" 2>/dev/null | grep "Maximum" | awk '{print $NF}')
    if [ "$MAX" = "99999" ] || [ "$MAX" = "never" ]; then
        echo "  $user (password never expires)"
    fi
done
echo ""

# List SUID binaries
echo "--- SUID binaries (runs as file owner) ---"
find / -perm -4000 -type f 2>/dev/null | head -20
SUID_COUNT=$(find / -perm -4000 -type f 2>/dev/null | wc -l)
echo "Total SUID files: $SUID_COUNT"
echo ""

# Recent logins
echo "--- Last 10 logins ---"
last -n 10 -i 2>/dev/null || last -n 10
echo ""

# Failed login attempts (last 24 hours)
echo "--- Failed login attempts (last 24h) ---"
if command -v faillock > /dev/null 2>&1; then
    for user in $(awk -F: '$3 >= 1000 && $7 != "/sbin/nologin" {print $1}' /etc/passwd); do
        FAILS=$(faillock --user "$user" 2>/dev/null | grep -c "^[0-9]" || true)
        if [ "$FAILS" -gt 0 ]; then
            echo "  $user: $FAILS failed attempt(s)"
        fi
    done
else
    echo "  faillock not available"
fi
echo ""

# Users in wheel/sudo group
echo "--- Users with sudo/wheel access ---"
getent group wheel 2>/dev/null | awk -F: '{print $4}' | tr ',' '\n' | sort
echo ""

echo "========================================"
echo "  Audit complete"
echo "========================================"
