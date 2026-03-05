#!/bin/bash
# selinux-selective.sh - Selective SELinux enforcement
# Chapter 13: Linux Security - SELinux Best Practices
#
# Demonstrates how to selectively disable SELinux for specific
# domains instead of disabling it system-wide. This is the
# recommended approach when a service has SELinux issues:
#
# NEVER: setenforce 0 (disables for ALL services)
# INSTEAD: semanage permissive -a <domain_t> (single service)
#
# When to use enforcing mode:
#   - DMZ servers (web, mail, DNS facing the internet)
#   - Internet-facing services (httpd, nginx, postfix)
#   - Any system accessible from untrusted networks
#   - Multi-tenant servers (shared hosting)
#
# Run as root.

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BOLD}=== SELinux Selective Enforcement ===${NC}\n"

# ---------- Current State ----------
echo -e "${BOLD}[1] Current SELinux Status${NC}"
if ! command -v getenforce &>/dev/null; then
    echo "SELinux tools not installed"
    echo "Install: dnf install policycoreutils policycoreutils-python-utils"
    exit 1
fi

echo "Mode: $(getenforce)"
echo "Policy: $(sestatus | grep 'Loaded policy' | awk '{print $NF}')"
echo ""

# ---------- Permissive Domains ----------
echo -e "${BOLD}[2] Currently Permissive Domains${NC}"
PERM=$(semanage permissive -l 2>/dev/null)
echo "$PERM"
echo ""

# ---------- Usage Examples ----------
echo -e "${BOLD}[3] Selective Permissive Mode Examples${NC}"
echo ""
cat << 'EXAMPLES'
# --- Scenario: httpd is blocked by SELinux ---

# Step 1: Check what is being denied
ausearch -m AVC -ts recent | grep httpd
sealert -a /var/log/audit/audit.log

# Step 2: Set httpd domain to permissive (not the whole system!)
semanage permissive -a httpd_t
# Now httpd runs as if SELinux is off, but everything else stays enforcing

# Step 3: Check what would have been denied
ausearch -m AVC --just-action --raw | audit2allow

# Step 4: Create a proper policy module
ausearch -m AVC -ts recent | audit2allow -M my-httpd-fix
semodule -i my-httpd-fix.pp

# Step 5: Remove permissive mode (back to enforcing for httpd)
semanage permissive -d httpd_t

# --- Common domain names ---
# httpd_t       - Apache/nginx web server
# named_t       - BIND DNS server
# mysqld_t      - MySQL/MariaDB database
# postgresql_t  - PostgreSQL database
# samba_t       - Samba file sharing
# postfix_t     - Postfix mail server
# dovecot_t     - Dovecot IMAP/POP3
# container_t   - Podman/Docker containers

EXAMPLES

echo -e "${BOLD}[4] Common SELinux Fixes (before resorting to permissive)${NC}"
echo ""
cat << 'FIXES'
# Fix 1: Restore file contexts (most common fix)
# When files are created outside the expected location or moved with cp
restorecon -Rv /var/www/html/
restorecon -Rv /srv/samba/

# Fix 2: Set custom file contexts for non-standard paths
semanage fcontext -a -t httpd_sys_content_t "/srv/mywebsite(/.*)?"
restorecon -Rv /srv/mywebsite/

# Fix 3: Toggle booleans for known use cases
# Allow httpd to connect to the network (for reverse proxy)
setsebool -P httpd_can_network_connect on

# Allow httpd to connect to databases
setsebool -P httpd_can_network_connect_db on

# Allow Samba to share home directories
setsebool -P samba_enable_home_dirs on

# Fix 4: Allow non-standard ports
semanage port -a -t http_port_t -p tcp 8443
semanage port -a -t ssh_port_t -p tcp 2222

FIXES

echo ""
echo -e "${BOLD}[5] Decision Guide${NC}"
echo ""
echo -e "${GREEN}Keep Enforcing:${NC}"
echo "  - Internet-facing services (web, mail, DNS)"
echo "  - DMZ servers"
echo "  - Multi-user/multi-tenant systems"
echo "  - Servers handling sensitive data"
echo ""
echo -e "${YELLOW}Selective Permissive (semanage permissive -a domain_t):${NC}"
echo "  - Troubleshooting a specific service"
echo "  - Third-party software without SELinux policy"
echo "  - Temporary measure while developing custom policy"
echo ""
echo -e "${RED}NEVER do this:${NC}"
echo "  - setenforce 0         (disables for everything)"
echo "  - SELINUX=disabled      (requires reboot, full relabel to re-enable)"
echo "  - SELINUX=permissive   (logs but never blocks anything)"
echo ""
echo "The above three options remove ALL SELinux protection."
echo "Use selective permissive mode instead."

echo ""
echo -e "${BOLD}=== SELinux Selective Enforcement Guide Complete ===${NC}"
