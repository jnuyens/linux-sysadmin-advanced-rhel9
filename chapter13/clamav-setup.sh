#!/bin/bash
# clamav-setup.sh - Install and configure ClamAV on RHEL 9
# Chapter 13: Linux Security - Antivirus for Ecosystem Protection
#
# ClamAV on Linux protects the ECOSYSTEM, not primarily Linux itself.
# Use cases:
#   - Samba file server scanning (block Windows malware on shared drives)
#   - Mail gateway scanning (Postfix + ClamAV + amavisd-new)
#   - Web upload scanning (scan user-uploaded files)
#
# Why Linux itself rarely needs antivirus:
#   - Strong user/root privilege separation
#   - Signed package repositories (dnf/rpm GPG verification)
#   - Rapid open-source patching (days, not weeks)
#   - Diverse architectures make mass exploitation difficult
#   - Despite 10x more Linux systems than Windows globally
#     (servers, embedded devices, Android, IoT), Linux malware
#     remains extremely rare due to these architectural advantages
#
# Run as root.

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BOLD}=== ClamAV Setup for RHEL 9 ===${NC}\n"

# ---------- Install ----------
echo -e "${BOLD}[1] Installing ClamAV${NC}"
if ! rpm -q clamav clamav-update clamd &>/dev/null; then
    dnf install -y epel-release
    dnf install -y clamav clamav-update clamd clamav-filesystem
    echo -e "${GREEN}ClamAV installed${NC}"
else
    echo "ClamAV already installed"
fi
echo ""

# ---------- Update Signatures ----------
echo -e "${BOLD}[2] Updating Virus Signatures${NC}"
# Fix SELinux context for freshclam if needed
if command -v restorecon &>/dev/null; then
    restorecon -Rv /var/lib/clamav/ 2>/dev/null || true
fi

# Update signatures
freshclam 2>/dev/null || echo -e "${YELLOW}freshclam update failed - check network and /etc/freshclam.conf${NC}"
echo ""

# ---------- Configure clamd ----------
echo -e "${BOLD}[3] Configuring clamd${NC}"
CLAMD_CONF="/etc/clamd.d/scan.conf"
if [ -f "$CLAMD_CONF" ]; then
    # Remove the Example line that prevents clamd from starting
    sed -i 's/^Example/#Example/' "$CLAMD_CONF"

    # Set the local socket
    if ! grep -q "^LocalSocket" "$CLAMD_CONF"; then
        echo "LocalSocket /run/clamd.scan/clamd.sock" >> "$CLAMD_CONF"
    fi

    echo "clamd configuration: $CLAMD_CONF"
fi

# Enable and start clamd
systemctl enable --now clamd@scan 2>/dev/null || echo -e "${YELLOW}Could not start clamd@scan${NC}"
echo ""

# ---------- Freshclam Timer ----------
echo -e "${BOLD}[4] Setting Up Automatic Updates${NC}"
# freshclam.conf - remove Example line
FRESHCLAM_CONF="/etc/freshclam.conf"
if [ -f "$FRESHCLAM_CONF" ]; then
    sed -i 's/^Example/#Example/' "$FRESHCLAM_CONF"
fi

# Enable timer for regular updates
systemctl enable --now clamav-freshclam 2>/dev/null || \
    echo "Set up a cron job: 0 */4 * * * /usr/bin/freshclam --quiet"
echo ""

# ---------- On-demand Scanning ----------
echo -e "${BOLD}[5] Test Scan${NC}"
echo "Scanning /tmp as a test:"
clamscan --recursive --quiet /tmp 2>/dev/null && echo -e "${GREEN}Scan complete${NC}" || true
echo ""

# ---------- Samba VFS Integration ----------
echo -e "${BOLD}[6] Samba Integration (for file share scanning)${NC}"
cat << 'SAMBA_CONFIG'
# Add to /etc/samba/smb.conf under [share] sections:
#
# [shared]
#     path = /srv/samba/shared
#     vfs objects = clamav
#     clamav:socket = /run/clamd.scan/clamd.sock
#     clamav:onInfected = quarantine
#     clamav:quarantine = /srv/samba/quarantine
#
# This scans files on open/close and quarantines infected files.
# Users see "access denied" when trying to save infected files.
#
# Alternatively, use a scheduled scan approach:
#   clamscan --recursive --move=/quarantine /srv/samba/shared
#   (add to cron for periodic scanning)
SAMBA_CONFIG
echo ""

# ---------- Mail Gateway Integration ----------
echo -e "${BOLD}[7] Mail Gateway Integration (Postfix)${NC}"
cat << 'MAIL_CONFIG'
# For Postfix mail gateway scanning with amavisd-new:
#
# 1. Install: dnf install amavisd-new
# 2. amavisd-new uses clamd for scanning via socket
# 3. Configure /etc/amavisd/amavisd.conf:
#    $virus_admin = 'postmaster@yourdomain.com';
#    $final_virus_destiny = D_DISCARD;
#
# 4. Postfix main.cf:
#    content_filter = smtp-amavis:[127.0.0.1]:10024
#
# This setup scans all incoming and outgoing email for viruses,
# protecting Windows users who receive mail through your server.
MAIL_CONFIG
echo ""

echo -e "${BOLD}=== ClamAV Setup Complete ===${NC}"
echo ""
echo "Useful commands:"
echo "  clamscan -r /path        - Scan directory recursively"
echo "  clamscan -r --move=/quarantine /path  - Scan and quarantine"
echo "  freshclam                - Update virus signatures"
echo "  systemctl status clamd@scan  - Check daemon status"
echo "  clamdtop                 - Monitor clamd activity"
