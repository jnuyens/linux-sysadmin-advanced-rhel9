#!/bin/bash
# Log Error Checker - Chapter 11 Exercise
#
# Checks for new errors since the last run using journalctl cursors.
# Designed for cron or systemd timer - runs every 5-15 minutes.
#
# Usage:
#     bash check-errors.sh              # check and report
#     bash check-errors.sh --reset      # reset cursor (start fresh)
#
# Cron example (every 10 minutes):
#     */10 * * * * /opt/scripts/check-errors.sh 2>/dev/null
#
# The cursor file tracks position so each run only shows NEW errors.

set -euo pipefail

CURSOR_FILE="/var/tmp/check-errors-cursor"
PRIORITY="err"
MAILTO=""  # set to an email address for notifications

# ---------------------------------------------------------------
# Handle --reset flag
# ---------------------------------------------------------------
if [[ "${1:-}" == "--reset" ]]; then
    rm -f "$CURSOR_FILE"
    echo "Cursor reset. Next run will show all errors from current boot."
    exit 0
fi

# ---------------------------------------------------------------
# Build journalctl command
# ---------------------------------------------------------------
JOURNAL_CMD="journalctl -p $PRIORITY --no-pager -o short-precise"

if [[ -f "$CURSOR_FILE" ]]; then
    JOURNAL_CMD="$JOURNAL_CMD --cursor-file=$CURSOR_FILE --after-cursor"
else
    # First run - only check current boot
    JOURNAL_CMD="$JOURNAL_CMD -b --cursor-file=$CURSOR_FILE"
fi

# ---------------------------------------------------------------
# Capture new errors
# ---------------------------------------------------------------
ERRORS=$($JOURNAL_CMD 2>/dev/null || true)

if [[ -z "$ERRORS" ]]; then
    # No new errors - silent exit
    exit 0
fi

# ---------------------------------------------------------------
# Count and report
# ---------------------------------------------------------------
ERROR_COUNT=$(echo "$ERRORS" | wc -l)
HOSTNAME=$(hostname -s)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

REPORT="[$TIMESTAMP] $HOSTNAME: $ERROR_COUNT new error(s) since last check

$ERRORS"

# Log to syslog
logger -t check-errors -p local0.warning "$ERROR_COUNT new errors detected"

# Print to stdout (captured by cron for email)
echo "$REPORT"

# Optional: send email
if [[ -n "$MAILTO" ]] && command -v mail &>/dev/null; then
    echo "$REPORT" | mail -s "[$HOSTNAME] $ERROR_COUNT new log errors" "$MAILTO"
fi

exit "$ERROR_COUNT"
