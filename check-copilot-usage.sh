#!/bin/bash

# GitHub Copilot Premium Request Usage Checker
# Checks premium model request usage and provides daily recommendations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== GitHub Copilot Premium Request Usage ===${NC}\n"

# Check if gh CLI is available and authenticated
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: gh CLI not found. Please install it first.${NC}"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo -e "${RED}Error: Not authenticated with gh CLI. Run 'gh auth login' first.${NC}"
    exit 1
fi

# Check for required commands
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq not found. Install with: sudo apt-get install -y jq${NC}"
    exit 1
fi

if ! command -v bc &> /dev/null; then
    echo -e "${RED}Error: bc not found. Install with: sudo apt-get install -y bc${NC}"
    exit 1
fi

# Fetch Copilot usage from the internal API
echo "Fetching Copilot usage data..."
USAGE_DATA=$(gh api /copilot_internal/user 2>&1)

if echo "$USAGE_DATA" | grep -q "Not Found\|Forbidden"; then
    echo -e "${RED}Error: Unable to access Copilot usage API.${NC}"
    echo "This might mean:"
    echo "  1. You don't have an active Copilot subscription"
    echo "  2. The API endpoint has changed"
    echo ""
    echo "Try checking manually at: https://github.com/settings/billing"
    exit 1
fi

# Save for debugging
echo "$USAGE_DATA" > /tmp/gh-copilot-usage.json

# Extract user info
USERNAME=$(echo "$USAGE_DATA" | jq -r '.login')
COPILOT_PLAN=$(echo "$USAGE_DATA" | jq -r '.copilot_plan')

echo -e "User: ${GREEN}${USERNAME}${NC}"
echo -e "Plan: ${CYAN}${COPILOT_PLAN}${NC}"
echo ""

# Extract premium interactions quota
LIMIT_REQUESTS=$(echo "$USAGE_DATA" | jq -r '.quota_snapshots.premium_interactions.entitlement // 0')
REMAINING_REQUESTS=$(echo "$USAGE_DATA" | jq -r '.quota_snapshots.premium_interactions.remaining // 0')
PERCENT_REMAINING=$(echo "$USAGE_DATA" | jq -r '.quota_snapshots.premium_interactions.percent_remaining // 0')
RESET_DATE=$(echo "$USAGE_DATA" | jq -r '.quota_reset_date')
UNLIMITED=$(echo "$USAGE_DATA" | jq -r '.quota_snapshots.premium_interactions.unlimited // false')

if [ "$UNLIMITED" = "true" ]; then
    echo -e "${GREEN}✓ You have UNLIMITED premium requests!${NC}"
    echo "No quota tracking needed."
    exit 0
fi

if [ "$LIMIT_REQUESTS" -eq 0 ]; then
    echo -e "${YELLOW}No premium request quota found.${NC}"
    echo "This might mean premium requests aren't available on your plan."
    exit 0
fi

# Calculate used requests
USED_REQUESTS=$((LIMIT_REQUESTS - REMAINING_REQUESTS))
RESET_TIME="$RESET_DATE"

# Current time
CURRENT_TIME=$(date +%s)

# Display Copilot Premium Request Usage
echo -e "\n${GREEN}Copilot Premium Model Requests:${NC}"
echo "  Total Limit:      $LIMIT_REQUESTS requests"
echo "  Remaining:        $REMAINING_REQUESTS requests"
USED_REQUESTS=$((LIMIT_REQUESTS - REMAINING_REQUESTS))
echo "  Used:             $USED_REQUESTS requests"

# Calculate usage percentage
if [ "$LIMIT_REQUESTS" -gt 0 ]; then
    USAGE_PCT=$(echo "scale=1; ($USED_REQUESTS * 100) / $LIMIT_REQUESTS" | bc)
    echo "  Usage:            ${USAGE_PCT}%"
    
    if [ -n "$RESET_TIME" ] && [ "$RESET_TIME" != "null" ]; then
        RESET_TIMESTAMP=$(date -d "$RESET_TIME" +%s 2>/dev/null || echo 0)
        if [ "$RESET_TIMESTAMP" -gt 0 ]; then
            TIME_UNTIL_RESET=$((RESET_TIMESTAMP - CURRENT_TIME))
            HOURS_UNTIL_RESET=$(echo "scale=1; $TIME_UNTIL_RESET / 3600" | bc)
            DAYS_UNTIL_RESET=$(echo "scale=1; $TIME_UNTIL_RESET / 86400" | bc)
            RESET_DATE=$(date -d "$RESET_TIME" "+%Y-%m-%d %H:%M:%S")
            echo "  Resets at:        $RESET_DATE"
            
            if (( $(echo "$DAYS_UNTIL_RESET > 1" | bc -l) )); then
                echo "  Time until reset: ${DAYS_UNTIL_RESET} days"
            else
                echo "  Time until reset: ${HOURS_UNTIL_RESET} hours"
            fi
        fi
    fi
fi

# Calculate daily recommendation
echo -e "\n${YELLOW}=== Daily Usage Recommendations ===${NC}"

if [ "$LIMIT_REQUESTS" -eq 0 ]; then
    echo -e "${RED}No usage data available.${NC}"
else
    # Determine if this is monthly, daily, or hourly
    # Most likely monthly for premium tier
    if [ -n "$RESET_TIME" ] && [ "$RESET_TIME" != "null" ]; then
        RESET_TIMESTAMP=$(date -d "$RESET_TIME" +%s 2>/dev/null || echo 0)
        if [ "$RESET_TIMESTAMP" -gt 0 ]; then
            TIME_UNTIL_RESET=$((RESET_TIMESTAMP - CURRENT_TIME))
            DAYS_UNTIL_RESET=$(echo "scale=0; $TIME_UNTIL_RESET / 86400" | bc)
            
            if [ "$DAYS_UNTIL_RESET" -gt 0 ] && [ "$REMAINING_REQUESTS" -gt 0 ]; then
                # Calculate daily budget
                DAILY_BUDGET=$(echo "scale=0; $REMAINING_REQUESTS / $DAYS_UNTIL_RESET" | bc)
                
                echo -e "  ${GREEN}Recommended daily budget: $DAILY_BUDGET requests/day${NC}"
                echo "  (Based on $REMAINING_REQUESTS requests over $DAYS_UNTIL_RESET days)"
                
                # Calculate hourly rate (assuming 8-12 hour workday)
                CONSERVATIVE_HOURLY=$(echo "scale=1; $DAILY_BUDGET / 12" | bc)
                MODERATE_HOURLY=$(echo "scale=1; $DAILY_BUDGET / 10" | bc)
                AGGRESSIVE_HOURLY=$(echo "scale=1; $DAILY_BUDGET / 8" | bc)
                
                echo ""
                echo "  Usage patterns:"
                echo "    Conservative (12h/day): ~${CONSERVATIVE_HOURLY} requests/hour"
                echo "    Moderate (10h/day):     ~${MODERATE_HOURLY} requests/hour"
                echo "    Focused (8h/day):       ~${AGGRESSIVE_HOURLY} requests/hour"
            fi
        fi
    fi
    
    # Warning if running low
    WARNING_THRESHOLD=$(echo "scale=0; $LIMIT_REQUESTS * 0.25" | bc | cut -d. -f1)
    NOTICE_THRESHOLD=$(echo "scale=0; $LIMIT_REQUESTS * 0.50" | bc | cut -d. -f1)
    
    if (( REMAINING_REQUESTS < WARNING_THRESHOLD )); then
        echo -e "\n  ${RED}⚠  WARNING: Less than 25% of requests remaining!${NC}"
        echo -e "  ${YELLOW}Consider conserving requests until reset.${NC}"
    elif (( REMAINING_REQUESTS < NOTICE_THRESHOLD )); then
        echo -e "\n  ${YELLOW}⚠  NOTICE: Less than 50% of requests remaining.${NC}"
        echo -e "  Monitor usage to avoid hitting limits."
    fi
fi

echo ""
