#!/bin/bash
# pre-commit hook - Chapter 8 Exercise
# Usage: cp pre-commit-hook.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
#
# This hook runs before every commit and prevents accidental
# inclusion of secrets, large files, and common mistakes.

set -euo pipefail

echo "Running pre-commit checks..."

ERRORS=0

# Check for common secret patterns in staged files
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACMR)

if [ -z "$STAGED_FILES" ]; then
    echo "No staged files to check."
    exit 0
fi

# Check for private keys
for file in $STAGED_FILES; do
    if [ -f "$file" ]; then
        # Check for private key headers
        if grep -q "PRIVATE KEY" "$file" 2>/dev/null; then
            echo "ERROR: Possible private key found in $file"
            ERRORS=$((ERRORS + 1))
        fi

        # Check for AWS credentials
        if grep -qE "(AKIA[A-Z0-9]{16}|aws_secret_access_key)" "$file" 2>/dev/null; then
            echo "ERROR: Possible AWS credentials in $file"
            ERRORS=$((ERRORS + 1))
        fi

        # Check for common password patterns
        if grep -qiE "(password|passwd|secret)\s*[:=]\s*['\"][^'\"]+['\"]" "$file" 2>/dev/null; then
            echo "WARNING: Possible hardcoded password in $file"
            ERRORS=$((ERRORS + 1))
        fi
    fi
done

# Check for large files (> 5MB)
for file in $STAGED_FILES; do
    if [ -f "$file" ]; then
        SIZE=$(wc -c < "$file")
        if [ "$SIZE" -gt 5242880 ]; then
            SIZE_MB=$((SIZE / 1048576))
            echo "ERROR: Large file ${file} (${SIZE_MB}MB). Use Git LFS for files > 5MB."
            ERRORS=$((ERRORS + 1))
        fi
    fi
done

# Check for common files that shouldn't be committed
for file in $STAGED_FILES; do
    case "$file" in
        *.env|.env.*|*.key|*.pem|id_rsa*|id_ed25519)
            echo "ERROR: Sensitive file staged: $file (add to .gitignore)"
            ERRORS=$((ERRORS + 1))
            ;;
    esac
done

if [ "$ERRORS" -gt 0 ]; then
    echo ""
    echo "Commit blocked: $ERRORS issue(s) found."
    echo "Fix the issues above or use 'git commit --no-verify' to bypass (not recommended)."
    exit 1
fi

echo "All checks passed."
exit 0
