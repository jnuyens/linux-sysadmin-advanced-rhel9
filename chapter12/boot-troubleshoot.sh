#!/bin/bash
# boot-troubleshoot.sh - Boot and startup diagnostic helper
# Chapter 12: Troubleshooting & Problem Determination
#
# Gathers boot timing analysis, startup failures, and GRUB configuration.
# Run as root.

set -euo pipefail

BOLD='\033[1m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${BOLD}=== Boot Troubleshooting Report ===${NC}\n"

# ---------- Boot Time Analysis ----------
echo -e "${BOLD}[1] Boot Time Summary${NC}"
systemd-analyze 2>/dev/null || echo "systemd-analyze not available"
echo ""

echo -e "${BOLD}[2] Slowest 10 Services at Boot${NC}"
systemd-analyze blame 2>/dev/null | head -10
echo ""

echo -e "${BOLD}[3] Critical Chain (boot critical path)${NC}"
systemd-analyze critical-chain 2>/dev/null | head -20
echo ""

# ---------- Boot Log ----------
echo -e "${BOLD}[4] Current Boot Errors${NC}"
BOOT_ERRORS=$(journalctl -b -p err --no-pager -q 2>/dev/null | wc -l)
echo "Errors this boot: $BOOT_ERRORS"
if [ "$BOOT_ERRORS" -gt 0 ]; then
    echo -e "${YELLOW}First 10 errors:${NC}"
    journalctl -b -p err --no-pager -q -n 10 2>/dev/null
fi
echo ""

# ---------- Previous Boot Check ----------
echo -e "${BOLD}[5] Previous Boot Check${NC}"
if journalctl --list-boots 2>/dev/null | head -5; then
    PREV_ERRORS=$(journalctl -b -1 -p err --no-pager -q 2>/dev/null | wc -l || echo 0)
    echo "Previous boot errors: $PREV_ERRORS"
else
    echo "No previous boot logs (persistent journal may not be configured)"
    echo ""
    echo -e "${YELLOW}To enable persistent journal storage:${NC}"
    echo "  mkdir -p /var/log/journal"
    echo "  systemd-tmpfiles --create --prefix /var/log/journal"
    echo "  systemctl restart systemd-journald"
fi
echo ""

# ---------- GRUB Configuration ----------
echo -e "${BOLD}[6] GRUB Default Configuration${NC}"
if [ -f /etc/default/grub ]; then
    grep -E "^GRUB_" /etc/default/grub 2>/dev/null
else
    echo "/etc/default/grub not found"
fi
echo ""

# ---------- Default Target ----------
echo -e "${BOLD}[7] Default Systemd Target${NC}"
systemctl get-default 2>/dev/null
echo ""

# ---------- Kernel Parameters ----------
echo -e "${BOLD}[8] Current Kernel Command Line${NC}"
cat /proc/cmdline 2>/dev/null
echo ""

# ---------- Dracut/Initramfs ----------
echo -e "${BOLD}[9] Current Initramfs${NC}"
KERNEL=$(uname -r)
INITRD="/boot/initramfs-${KERNEL}.img"
if [ -f "$INITRD" ]; then
    echo "Initramfs: $INITRD"
    ls -lh "$INITRD"
    echo -e "\nTo inspect contents: lsinitrd $INITRD | head -50"
else
    echo -e "${RED}Expected initramfs not found: $INITRD${NC}"
fi
echo ""

echo -e "${BOLD}=== Boot Troubleshooting Complete ===${NC}"
echo ""
echo "Recovery tips:"
echo "  - Edit kernel params at GRUB: press 'e' at boot menu"
echo "  - Single user mode: append 'systemd.unit=rescue.target' to kernel line"
echo "  - Emergency shell: append 'systemd.unit=emergency.target'"
echo "  - Root password reset: append 'rd.break' for initramfs shell"
echo "    Then: mount -o remount,rw /sysroot && chroot /sysroot && passwd root"
