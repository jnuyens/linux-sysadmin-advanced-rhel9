#!/bin/bash
# aide-setup.sh - Install and configure AIDE file integrity monitoring
# Chapter 13: Linux Security - Breach Detection
#
# AIDE (Advanced Intrusion Detection Environment) monitors critical
# system files for unauthorized changes. It creates a database of
# file checksums, permissions, and metadata, then detects modifications.
#
# Use case: Detect if an attacker modifies system binaries, config
# files, or adds backdoors. Run checks regularly via cron.
#
# Run as root.

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BOLD}=== AIDE File Integrity Monitoring Setup ===${NC}\n"

# ---------- Install ----------
echo -e "${BOLD}[1] Installing AIDE${NC}"
if ! rpm -q aide &>/dev/null; then
    dnf install -y aide
    echo -e "${GREEN}AIDE installed${NC}"
else
    echo "AIDE already installed"
fi
echo ""

# ---------- Configure ----------
echo -e "${BOLD}[2] AIDE Configuration${NC}"
AIDE_CONF="/etc/aide.conf"
echo "Configuration file: $AIDE_CONF"
echo ""
echo "Default monitored paths include:"
echo "  /boot, /bin, /sbin, /lib, /lib64"
echo "  /usr/bin, /usr/sbin, /usr/lib, /usr/lib64"
echo "  /etc"
echo ""
echo "Default exclusions:"
echo "  /var/log, /var/spool, /var/run, /var/lib"
echo ""

# Show key configuration directives
echo "Key AIDE rules in $AIDE_CONF:"
echo "  NORMAL = p+i+n+u+g+s+m+c+acl+selinux+xattrs+sha512"
echo "  PERMS  = p+u+g+acl+selinux+xattrs"
echo "  LOG    = p+u+g+n+acl+selinux+ftype"
echo ""
echo "  p=permissions i=inode n=links u=user g=group s=size"
echo "  m=mtime c=ctime acl=ACLs selinux=context sha512=checksum"
echo ""

# ---------- Initialize Database ----------
echo -e "${BOLD}[3] Initializing AIDE Database${NC}"
echo "This creates the baseline database of file checksums."
echo "It takes several minutes on a full system..."
echo ""

if [ ! -f /var/lib/aide/aide.db.gz ]; then
    echo "Running: aide --init"
    aide --init 2>/dev/null
    echo ""

    # Move the new database to the active location
    if [ -f /var/lib/aide/aide.db.new.gz ]; then
        cp /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
        echo -e "${GREEN}Database initialized and activated${NC}"
    fi
else
    echo -e "${YELLOW}Database already exists at /var/lib/aide/aide.db.gz${NC}"
    echo "To reinitialize: aide --init && cp /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz"
fi
echo ""

# ---------- Run Check ----------
echo -e "${BOLD}[4] Running AIDE Check${NC}"
echo "Comparing current filesystem against baseline..."
aide --check 2>/dev/null || true
echo ""

# ---------- Cron Job ----------
echo -e "${BOLD}[5] Setting Up Daily Check${NC}"
CRON_FILE="/etc/cron.daily/aide-check"
cat > "$CRON_FILE" << 'CRON'
#!/bin/bash
# Daily AIDE integrity check
# Results are mailed to root (configure /etc/aliases)
LOGFILE="/var/log/aide/aide-check-$(date +%Y%m%d).log"
mkdir -p /var/log/aide
/usr/sbin/aide --check > "$LOGFILE" 2>&1
CHANGES=$(grep -c "^(changed\|added\|removed)" "$LOGFILE" 2>/dev/null || echo "0")
if [ "$CHANGES" -gt 0 ]; then
    echo "AIDE detected $CHANGES change(s) on $(hostname)" | \
        mail -s "AIDE Alert: $(hostname)" root 2>/dev/null || true
fi
# Rotate: keep 30 days of logs
find /var/log/aide -name "aide-check-*.log" -mtime +30 -delete 2>/dev/null
CRON
chmod +x "$CRON_FILE"
echo -e "${GREEN}Daily check installed: $CRON_FILE${NC}"
echo ""

# ---------- Update Database ----------
echo -e "${BOLD}[6] Updating the Database${NC}"
echo "After legitimate changes (e.g., patching), update the baseline:"
echo ""
echo "  aide --update"
echo "  cp /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz"
echo ""
echo "IMPORTANT: Store a copy of aide.db.gz on read-only media or a"
echo "separate system. If an attacker compromises the server, they could"
echo "also modify the AIDE database to hide their changes."
echo ""

echo -e "${BOLD}=== AIDE Setup Complete ===${NC}"
echo ""
echo "Commands:"
echo "  aide --check              - Check for changes"
echo "  aide --update             - Create updated database"
echo "  aide --init               - Reinitialize from scratch"
echo "  aide --compare            - Compare two databases"
