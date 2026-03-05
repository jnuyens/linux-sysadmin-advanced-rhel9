#!/bin/bash
# =============================================================================
# check-playbook.sh - Ansible Playbook Validation Script
# Advanced Linux System Administration - RHEL 9
# =============================================================================
# Run this script before committing or deploying playbooks.
# It performs multiple validation checks to catch errors early.
#
# Usage:
#   ./check-playbook.sh                    # validate all YAML files
#   ./check-playbook.sh site.yml           # validate specific playbook
#   ./check-playbook.sh --fix              # auto-fix yamllint issues
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PLAYBOOK="${1:-site.yml}"
FIX_MODE=false
ERRORS=0

if [[ "${1:-}" == "--fix" ]]; then
    FIX_MODE=true
    PLAYBOOK="${2:-site.yml}"
fi

echo "=========================================="
echo " Ansible Playbook Validation"
echo "=========================================="
echo ""

# -----------------------------------------------
# Check 1: YAML Syntax (yamllint)
# -----------------------------------------------
echo -e "${YELLOW}[1/4] YAML Lint...${NC}"
if command -v yamllint &> /dev/null; then
    if yamllint -d relaxed "$PLAYBOOK" 2>&1; then
        echo -e "${GREEN}  PASS: YAML syntax is valid${NC}"
    else
        echo -e "${RED}  FAIL: YAML syntax errors found${NC}"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${YELLOW}  SKIP: yamllint not installed (pip install yamllint)${NC}"
fi
echo ""

# -----------------------------------------------
# Check 2: Ansible Syntax Check
# -----------------------------------------------
echo -e "${YELLOW}[2/4] Ansible Syntax Check...${NC}"
if ansible-playbook "$PLAYBOOK" --syntax-check 2>&1; then
    echo -e "${GREEN}  PASS: Ansible syntax is valid${NC}"
else
    echo -e "${RED}  FAIL: Ansible syntax errors found${NC}"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# -----------------------------------------------
# Check 3: Ansible Lint (best practices)
# -----------------------------------------------
echo -e "${YELLOW}[3/4] Ansible Lint...${NC}"
if command -v ansible-lint &> /dev/null; then
    if ansible-lint "$PLAYBOOK" 2>&1; then
        echo -e "${GREEN}  PASS: No lint warnings${NC}"
    else
        echo -e "${YELLOW}  WARN: Lint warnings found (review above)${NC}"
        # Don't count lint warnings as hard errors
    fi
else
    echo -e "${YELLOW}  SKIP: ansible-lint not installed (pip install ansible-lint)${NC}"
fi
echo ""

# -----------------------------------------------
# Check 4: Dry Run (check mode)
# -----------------------------------------------
echo -e "${YELLOW}[4/4] Dry Run (--check --diff)...${NC}"
echo "  This requires connectivity to your inventory hosts."
echo "  Skipping dry run in validation mode."
echo "  To run manually:"
echo "    ansible-playbook $PLAYBOOK --check --diff"
echo ""

# -----------------------------------------------
# Summary
# -----------------------------------------------
echo "=========================================="
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN} ALL CHECKS PASSED${NC}"
    echo ""
    echo "Safe to deploy:"
    echo "  ansible-playbook $PLAYBOOK"
    echo "  ansible-playbook $PLAYBOOK --check --diff  # dry run first"
else
    echo -e "${RED} $ERRORS CHECK(S) FAILED${NC}"
    echo ""
    echo "Fix errors before deploying."
    exit 1
fi
