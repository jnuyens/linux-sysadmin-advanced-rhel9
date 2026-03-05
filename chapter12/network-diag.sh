#!/bin/bash
# network-diag.sh - Layered network diagnostics
# Chapter 12: Troubleshooting & Problem Determination
#
# Walks through network troubleshooting layer by layer:
# Physical -> Data Link -> Network -> Transport -> Application
# Run as root for full diagnostics.

set -euo pipefail

BOLD='\033[1m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

TARGET="${1:-8.8.8.8}"
echo -e "${BOLD}=== Network Diagnostics - Target: $TARGET ===${NC}\n"

# ---------- Layer 1: Physical / Link ----------
echo -e "${BOLD}[Layer 1-2] Physical & Data Link${NC}"
echo "Interface status:"
ip -br link show 2>/dev/null | while read -r iface state rest; do
    if [ "$state" = "UP" ]; then
        echo -e "  ${GREEN}$iface: $state${NC} $rest"
    elif [ "$state" = "DOWN" ]; then
        echo -e "  ${RED}$iface: $state${NC}"
    else
        echo "  $iface: $state $rest"
    fi
done
echo ""

# Check for carrier errors
echo "Interface statistics (errors/drops):"
for iface in $(ip -br link show | awk '{print $1}' | grep -v lo); do
    RX_ERR=$(cat "/sys/class/net/$iface/statistics/rx_errors" 2>/dev/null || echo "?")
    TX_ERR=$(cat "/sys/class/net/$iface/statistics/tx_errors" 2>/dev/null || echo "?")
    RX_DROP=$(cat "/sys/class/net/$iface/statistics/rx_dropped" 2>/dev/null || echo "?")
    TX_DROP=$(cat "/sys/class/net/$iface/statistics/tx_dropped" 2>/dev/null || echo "?")
    echo "  $iface: rx_errors=$RX_ERR tx_errors=$TX_ERR rx_dropped=$RX_DROP tx_dropped=$TX_DROP"
done
echo ""

# ---------- Layer 3: Network ----------
echo -e "${BOLD}[Layer 3] Network Layer${NC}"
echo "IP addresses:"
ip -br addr show 2>/dev/null | grep -v "^lo"
echo ""

echo "Default route:"
ip route show default 2>/dev/null || echo "No default route!"
echo ""

echo "Routing table:"
ip route show 2>/dev/null | head -10
echo ""

GATEWAY=$(ip route show default 2>/dev/null | awk '{print $3; exit}')
if [ -n "$GATEWAY" ]; then
    echo "Ping gateway ($GATEWAY):"
    if ping -c 2 -W 2 "$GATEWAY" &>/dev/null; then
        echo -e "  ${GREEN}Gateway reachable${NC}"
    else
        echo -e "  ${RED}Gateway unreachable - check Layer 1-2 and IP config${NC}"
    fi
else
    echo -e "${RED}No default gateway configured${NC}"
fi
echo ""

echo "Ping target ($TARGET):"
if ping -c 2 -W 3 "$TARGET" &>/dev/null; then
    echo -e "  ${GREEN}Target reachable${NC}"
else
    echo -e "  ${RED}Target unreachable - check routing and firewall${NC}"
fi
echo ""

# ---------- DNS ----------
echo -e "${BOLD}[Layer 3.5] DNS Resolution${NC}"
echo "DNS configuration:"
if [ -f /etc/resolv.conf ]; then
    grep -E "^(nameserver|search|domain)" /etc/resolv.conf
else
    echo "No /etc/resolv.conf found"
fi
echo ""

echo "DNS test (resolve google.com):"
if host google.com &>/dev/null 2>&1; then
    host google.com 2>/dev/null | head -2
    echo -e "  ${GREEN}DNS resolution working${NC}"
elif dig google.com +short &>/dev/null 2>&1; then
    dig google.com +short 2>/dev/null | head -2
    echo -e "  ${GREEN}DNS resolution working${NC}"
else
    echo -e "  ${RED}DNS resolution failed${NC}"
fi
echo ""

# ---------- Layer 4: Transport ----------
echo -e "${BOLD}[Layer 4] Transport Layer${NC}"
echo "Listening services:"
ss -tlnp 2>/dev/null | head -15
echo ""

echo "Firewall rules (nftables):"
if command -v nft &>/dev/null; then
    nft list ruleset 2>/dev/null | head -20
    echo "  (truncated - run 'nft list ruleset' for full output)"
else
    echo "nft not available"
fi
echo ""

echo "Firewalld active zones:"
if command -v firewall-cmd &>/dev/null; then
    firewall-cmd --get-active-zones 2>/dev/null
    echo ""
    echo "Allowed services in default zone:"
    firewall-cmd --list-services 2>/dev/null
fi
echo ""

# ---------- Layer 7: Application ----------
echo -e "${BOLD}[Layer 7] Application Layer${NC}"
echo "Common service ports check:"
for port in 22 80 443; do
    if ss -tln 2>/dev/null | grep -q ":${port} "; then
        echo -e "  Port $port: ${GREEN}listening${NC}"
    else
        echo -e "  Port $port: ${YELLOW}not listening${NC}"
    fi
done
echo ""

echo -e "${BOLD}=== Network Diagnostics Complete ===${NC}"
echo ""
echo "Next steps if issues found:"
echo "  Layer 1-2: Check cables, switch ports, ethtool <iface>"
echo "  Layer 3:   Check IP config (nmcli), routes, ARP (ip neigh)"
echo "  DNS:       Test with dig @<server> <domain>, check /etc/resolv.conf"
echo "  Layer 4:   Check firewalld rules, ss -tlnp for listeners"
echo "  Layer 7:   Check service config, journalctl -u <service>"
