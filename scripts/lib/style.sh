#!/bin/bash
# Style definitions: colors and status strings

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Output symbols (prefixed to avoid collision with Nagios codes)
CHECK_PASS="${GREEN}✓${RESET}"
CHECK_FAIL="${RED}✗${RESET}"
CHECK_WARN="${YELLOW}!${RESET}"
CHECK_INFO="${BLUE}ℹ${RESET}"
CHECK_UNKNOWN="${CYAN}?${RESET}"
CHECK_MDM="${MAGENTA}⚙${RESET}"

# Status codes (Nagios exit codes plus UNKNOWN; see ADR-0003)
OK=0; WARN=1; CRIT=2; INFO=3; UNKNOWN=4

# Status strings (for consistency)
ENABLED="Enabled"
DISABLED="Disabled"
YES="Yes"
NO="No"
ON="On"
OFF="Off"
INSTALLED="Installed"
NOT_INSTALLED="Not installed"
LISTENING="Listening"
NOT_LISTENING="Not listening"
ALLOWED="Allowed"
BLOCKED="Blocked"
ENROLLED="Enrolled"
NOT_ENROLLED="Not enrolled"
FOUND="Found"
NOT_FOUND="Not found"
SECURE="Secure"
PREFERRED="Preferred"
NOT_PREFERRED="Not preferred"
