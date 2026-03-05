#!/bin/bash
# firewall-zones.sh - Firewalld zone configuration examples
# Chapter 13: Linux Security - Network Security
#
# Demonstrates firewalld zone-based security for RHEL 9.
# Shows DMZ, internal, and external zone configurations.
# Run as root.

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BOLD}=== Firewalld Zone Configuration Examples ===${NC}\n"

# ---------- Current Status ----------
echo -e "${BOLD}[1] Current Firewall Status${NC}"
firewall-cmd --state 2>/dev/null || { echo "firewalld not running"; exit 1; }
echo ""

echo "Available zones:"
firewall-cmd --get-zones
echo ""

echo "Active zones:"
firewall-cmd --get-active-zones
echo ""

echo "Default zone: $(firewall-cmd --get-default-zone)"
echo ""

# ---------- Zone Configuration Examples ----------
echo -e "${BOLD}[2] Zone Configuration Examples${NC}"
echo ""

cat << 'EXAMPLES'
# ============================================================
# Example 1: Web Server (DMZ zone)
# ============================================================
# Assign interface to DMZ zone
firewall-cmd --zone=dmz --change-interface=eth0 --permanent

# Allow only HTTP and HTTPS
firewall-cmd --zone=dmz --add-service=http --permanent
firewall-cmd --zone=dmz --add-service=https --permanent

# Remove SSH from DMZ (manage via separate interface)
firewall-cmd --zone=dmz --remove-service=ssh --permanent

# ============================================================
# Example 2: Internal Management Network
# ============================================================
# Create a management zone
firewall-cmd --zone=internal --change-interface=eth1 --permanent

# Allow SSH and monitoring
firewall-cmd --zone=internal --add-service=ssh --permanent
firewall-cmd --zone=internal --add-service=cockpit --permanent

# Allow specific port for monitoring agent
firewall-cmd --zone=internal --add-port=9090/tcp --permanent

# ============================================================
# Example 3: Database Server (strict access)
# ============================================================
# Allow PostgreSQL only from specific subnet
firewall-cmd --zone=internal --add-rich-rule='
    rule family="ipv4"
    source address="10.0.1.0/24"
    port port="5432" protocol="tcp"
    accept' --permanent

# Allow MySQL only from app servers
firewall-cmd --zone=internal --add-rich-rule='
    rule family="ipv4"
    source address="10.0.2.10"
    port port="3306" protocol="tcp"
    accept' --permanent

# ============================================================
# Example 4: Rate limiting SSH (anti-brute-force)
# ============================================================
# Limit SSH to 3 connections per minute per source IP
firewall-cmd --add-rich-rule='
    rule service name="ssh"
    accept limit value="3/m"' --permanent

# ============================================================
# Example 5: Logging dropped traffic
# ============================================================
# Log all dropped packets (useful for troubleshooting)
firewall-cmd --set-log-denied=all --permanent
# Options: all, unicast, broadcast, multicast, off

# ============================================================
# Apply all changes
# ============================================================
firewall-cmd --reload

EXAMPLES

echo ""
echo -e "${BOLD}[3] Firewall Limitations${NC}"
echo ""
cat << 'LIMITATIONS'
Traditional firewalls inspect packets at network/transport layers.
They CANNOT detect or prevent:

1. DNS Tunneling:
   - Attacker encodes C2 (command and control) data in DNS queries
   - Looks like normal DNS traffic to the firewall
   - Example: iodine, dnscat2 tools
   - Mitigation: Force DNS through internal resolver, monitor query patterns

2. HTTPS Command & Control:
   - Malware communicates via HTTPS to cloud services
   - Firewall sees encrypted traffic to "legitimate" hosts
   - Mitigation: TLS inspection (with privacy considerations), EDR

3. Authorized Protocol Abuse:
   - Data exfiltration via permitted protocols (HTTP POST, email)
   - Firewall allows the protocol, cannot inspect content
   - Mitigation: DLP solutions, behavioral analysis

4. Lateral Movement:
   - Once inside, attackers move between hosts on trusted networks
   - Internal firewalls help but add complexity
   - Mitigation: Network segmentation, zero-trust architecture

Defense in depth means firewalls are ONE layer, not THE defense.
LIMITATIONS

echo ""
echo -e "${BOLD}=== Firewall Configuration Guide Complete ===${NC}"
