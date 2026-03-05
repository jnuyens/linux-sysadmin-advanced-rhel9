#!/bin/bash
# check-rpm-integrity.sh - Verify RPM package integrity
# Chapter 12: Troubleshooting & Problem Determination
#
# Uses rpm -V to check if installed packages have been modified.
# Useful for troubleshooting unexpected behavior or security auditing.
# Run as root.

set -euo pipefail

BOLD='\033[1m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

PACKAGE="${1:-}"

echo -e "${BOLD}=== RPM Integrity Verification ===${NC}\n"

echo "RPM verification flags:"
echo "  S = file Size differs"
echo "  M = Mode (permissions/type) differs"
echo "  5 = digest (MD5/SHA) differs"
echo "  D = Device major/minor mismatch"
echo "  L = readLink path mismatch"
echo "  U = User ownership differs"
echo "  G = Group ownership differs"
echo "  T = mTime differs"
echo "  P = caPabilities differ"
echo "  c = %config file  d = %doc  g = %ghost  l = %license  r = %readme"
echo ""

if [ -n "$PACKAGE" ]; then
    echo -e "${BOLD}Verifying package: $PACKAGE${NC}"
    if ! rpm -q "$PACKAGE" &>/dev/null; then
        echo -e "${RED}Package '$PACKAGE' is not installed${NC}"
        exit 1
    fi
    echo ""
    OUTPUT=$(rpm -V "$PACKAGE" 2>/dev/null || true)
    if [ -z "$OUTPUT" ]; then
        echo -e "${GREEN}Package $PACKAGE: all files intact${NC}"
    else
        echo -e "${YELLOW}Modified files in $PACKAGE:${NC}"
        echo "$OUTPUT"
    fi
else
    echo -e "${BOLD}Verifying all critical system packages...${NC}"
    echo "(This may take a few minutes)"
    echo ""

    CRITICAL_PKGS=(
        "systemd"
        "openssh-server"
        "openssh-clients"
        "sudo"
        "pam"
        "shadow-utils"
        "coreutils"
        "util-linux"
        "firewalld"
        "selinux-policy"
        "bash"
        "glibc"
    )

    ISSUES=0
    for pkg in "${CRITICAL_PKGS[@]}"; do
        if rpm -q "$pkg" &>/dev/null; then
            OUTPUT=$(rpm -V "$pkg" 2>/dev/null || true)
            if [ -n "$OUTPUT" ]; then
                echo -e "${YELLOW}[$pkg] Modified files:${NC}"
                echo "$OUTPUT" | while read -r line; do
                    # Highlight size or digest changes (potential tampering)
                    if echo "$line" | grep -qE "^.{0,2}[5S]"; then
                        echo -e "  ${RED}$line${NC}"
                    else
                        echo "  $line"
                    fi
                done
                echo ""
                ISSUES=$((ISSUES + 1))
            fi
        fi
    done

    if [ "$ISSUES" -eq 0 ]; then
        echo -e "${GREEN}All critical packages verified - no modifications found${NC}"
    else
        echo -e "${YELLOW}$ISSUES package(s) have modified files${NC}"
        echo ""
        echo "Notes:"
        echo "  - Config file changes (marked 'c') are usually expected"
        echo "  - Size/digest changes on binaries may indicate tampering"
        echo "  - To reinstall a package: dnf reinstall <package>"
        echo "  - To undo last transaction: dnf history undo last"
    fi
fi

echo ""
echo -e "${BOLD}Additional RPM troubleshooting:${NC}"
echo "  rpm -qf /path/to/file        - Which package owns this file?"
echo "  rpm -ql <package>             - List all files in a package"
echo "  rpm -q --scripts <package>    - Show install/uninstall scripts"
echo "  dnf history list              - Recent package transactions"
echo "  dnf history info <id>         - Details of a transaction"
echo "  dnf history undo <id>         - Reverse a transaction"
