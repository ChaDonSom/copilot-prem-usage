#!/bin/bash

# GitHub Copilot Premium Request Usage Checker
# Checks premium model request usage and provides daily recommendations
# Supports optional remote server for cross-machine tracking

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
COPILOT_TRACKER_URL="${COPILOT_TRACKER_URL:-}"
FORCE_REFRESH=false
USE_LOCAL=false
SHOW_HELP=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --server)
            COPILOT_TRACKER_URL="$2"
            shift 2
            ;;
        --force-refresh)
            FORCE_REFRESH=true
            shift
            ;;
        --local)
            USE_LOCAL=true
            shift
            ;;
        --help|-h)
            SHOW_HELP=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

if [ "$SHOW_HELP" = true ]; then
    echo "GitHub Copilot Premium Usage Checker"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --server <URL>    Copilot Tracker server URL (or set COPILOT_TRACKER_URL env var)"
    echo "  --force-refresh   Force a fresh check from GitHub (when using server)"
    echo "  --local           Force local check even if server is available"
    echo "  --help, -h        Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  COPILOT_TRACKER_URL  Default server URL for cross-machine tracking"
    echo ""
    exit 0
fi

# Function to check if server is available
check_server_health() {
    local url="$1"
    if curl -sf --max-time 3 "${url}/health" > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Function to get GitHub token
get_github_token() {
    if command -v gh &> /dev/null && gh auth status &> /dev/null 2>&1; then
        gh auth token
    else
        echo ""
    fi
}

# Function to fetch usage from server
fetch_from_server() {
    local url="$1"
    local token="$2"
    local endpoint="/api/usage"
    
    if [ "$FORCE_REFRESH" = true ]; then
        endpoint="/api/usage/refresh"
        local http_code=$(curl -s -w "%{http_code}" -o /tmp/copilot-response.json --max-time 10 -X POST \
            -H "Authorization: Bearer $token" \
            -H "Accept: application/json" \
            "${url}${endpoint}")
    else
        local http_code=$(curl -s -w "%{http_code}" -o /tmp/copilot-response.json --max-time 10 \
            -H "Authorization: Bearer $token" \
            -H "Accept: application/json" \
            "${url}${endpoint}")
    fi
    
    local response=$(cat /tmp/copilot-response.json 2>/dev/null)
    
    if [ "$http_code" = "200" ] && [ -n "$response" ]; then
        echo "$response"
        return 0
    else
        echo -e "${RED}Server error (HTTP $http_code):${NC}" >&2
        if [ -n "$response" ]; then
            echo "$response" | jq -r '.message // .error // "Unknown error"' 2>/dev/null || echo "$response" >&2
        fi
        return 1
    fi
}

# Function to fetch today's usage from server
fetch_today_from_server() {
    local url="$1"
    local token="$2"
    
    local http_code=$(curl -s -w "%{http_code}" -o /tmp/copilot-today-response.json --max-time 10 \
        -H "Authorization: Bearer $token" \
        -H "Accept: application/json" \
        "${url}/api/usage/today")
    
    local response=$(cat /tmp/copilot-today-response.json 2>/dev/null)
    
    if [ "$http_code" = "200" ] && [ -n "$response" ]; then
        echo "$response"
        return 0
    fi
    return 1
}

# Function to display server-based results
display_server_results() {
    local usage_data="$1"
    local today_data="$2"
    
    local username=$(echo "$usage_data" | jq -r '.username')
    local copilot_plan=$(echo "$usage_data" | jq -r '.copilot_plan')
    local quota_limit=$(echo "$usage_data" | jq -r '.usage.quota_limit')
    local remaining=$(echo "$usage_data" | jq -r '.usage.remaining')
    local used=$(echo "$usage_data" | jq -r '.usage.used')
    local percent_remaining=$(echo "$usage_data" | jq -r '.usage.percent_remaining')
    local reset_date=$(echo "$usage_data" | jq -r '.usage.reset_date')
    local checked_at=$(echo "$usage_data" | jq -r '.checked_at')
    local cached=$(echo "$usage_data" | jq -r '.cached')
    
    echo -e "User: ${GREEN}${username}${NC}"
    echo -e "Plan: ${CYAN}${copilot_plan}${NC}"
    if [ "$cached" = "true" ]; then
        echo -e "Data: ${YELLOW}Cached${NC} (checked at: $checked_at)"
    else
        echo -e "Data: ${GREEN}Fresh${NC} (checked at: $checked_at)"
    fi
    echo ""
    
    echo -e "${GREEN}Copilot Premium Model Requests:${NC}"
    echo "  Total Limit:      $quota_limit requests"
    echo "  Remaining:        $remaining requests"
    echo "  Used:             $used requests"
    
    # Get today's usage from server
    local used_today=0
    if [ -n "$today_data" ]; then
        used_today=$(echo "$today_data" | jq -r '.used_today // 0')
    fi
    echo "  Used today (UTC): $used_today requests (tracked by server)"
    
    # Calculate usage percentage
    if [ "$quota_limit" -gt 0 ]; then
        local usage_pct=$(echo "scale=1; ($used * 100) / $quota_limit" | bc)
        echo "  Usage:            ${usage_pct}%"
        echo "  Resets at:        $reset_date"
    fi
    
    # Calculate recommendations
    echo -e "\n${YELLOW}=== Daily Usage Recommendations ===${NC}"
    
    local current_time=$(date +%s)
    local reset_timestamp=$(date -d "$reset_date" +%s 2>/dev/null || echo 0)
    if [ "$reset_timestamp" -gt 0 ]; then
        local time_until_reset=$((reset_timestamp - current_time))
        local days_until_reset=$(echo "scale=0; $time_until_reset / 86400" | bc)
        
        if [ "$days_until_reset" -gt 0 ] && [ "$remaining" -gt 0 ]; then
            local daily_budget=$(echo "scale=0; $remaining / $days_until_reset" | bc)
            
            echo -e "  ${GREEN}Recommended daily budget: $daily_budget requests/day${NC}"
            echo "  (Based on $remaining requests over $days_until_reset days)"
            
            echo ""
            echo -e "  ${CYAN}Today's usage (tracked by server):${NC}"
            echo "    Used today: $used_today requests"
            echo "    Daily budget: $daily_budget requests"
            
            local remaining_today=$((daily_budget - used_today))
            if [ $remaining_today -lt 0 ]; then
                local over_budget=$((remaining_today * -1))
                echo -e "    Status: ${RED}⚠ Over budget by $over_budget requests${NC}"
            elif [ $used_today -gt $((daily_budget * 3 / 4)) ]; then
                echo -e "    Status: ${YELLOW}⚠ Used ${used_today}/${daily_budget} (approaching limit)${NC}"
            else
                echo -e "    Status: ${GREEN}✓ Used ${used_today}/${daily_budget}${NC}"
            fi
        fi
    fi
    
    # Warnings
    local warning_threshold=$(echo "scale=0; $quota_limit * 0.25" | bc | cut -d. -f1)
    local notice_threshold=$(echo "scale=0; $quota_limit * 0.50" | bc | cut -d. -f1)
    
    if (( remaining < warning_threshold )); then
        echo -e "\n  ${RED}⚠  WARNING: Less than 25% of requests remaining!${NC}"
        echo -e "  ${YELLOW}Consider conserving requests until reset.${NC}"
    elif (( remaining < notice_threshold )); then
        echo -e "\n  ${YELLOW}⚠  NOTICE: Less than 50% of requests remaining.${NC}"
        echo -e "  Monitor usage to avoid hitting limits."
    fi
    
    echo ""
}

# Try to use server if available and not forced to use local
SERVER_AVAILABLE=false
if [ -n "$COPILOT_TRACKER_URL" ] && [ "$USE_LOCAL" = false ]; then
    echo -e "${BLUE}=== GitHub Copilot Premium Request Usage ===${NC}"
    echo -e "${CYAN}Checking server at ${COPILOT_TRACKER_URL}...${NC}"
    
    if check_server_health "$COPILOT_TRACKER_URL"; then
        SERVER_AVAILABLE=true
        GITHUB_TOKEN=$(get_github_token)
        
        if [ -z "$GITHUB_TOKEN" ]; then
            echo -e "${YELLOW}Warning: Could not get GitHub token. Falling back to local check.${NC}"
            SERVER_AVAILABLE=false
        else
            echo -e "${GREEN}Server available. Fetching usage data...${NC}\n"
            
            USAGE_RESPONSE=$(fetch_from_server "$COPILOT_TRACKER_URL" "$GITHUB_TOKEN")
            if [ $? -eq 0 ] && [ -n "$USAGE_RESPONSE" ]; then
                TODAY_RESPONSE=$(fetch_today_from_server "$COPILOT_TRACKER_URL" "$GITHUB_TOKEN")
                display_server_results "$USAGE_RESPONSE" "$TODAY_RESPONSE"
                exit 0
            else
                echo -e "${YELLOW}Failed to fetch from server. Falling back to local check.${NC}\n"
                SERVER_AVAILABLE=false
            fi
        fi
    else
        echo -e "${YELLOW}Server not available. Using local check.${NC}\n"
    fi
fi

# Only print header if we haven't already (i.e., server check wasn't attempted)
if [ -z "$COPILOT_TRACKER_URL" ] || [ "$USE_LOCAL" = true ]; then
    echo -e "${BLUE}=== GitHub Copilot Premium Request Usage ===${NC}\n"
fi

# Local check (fallback or explicit)

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

# Current time (UTC for quota reset tracking)
CURRENT_TIME=$(date +%s)
CURRENT_UTC_DATE=$(date -u +%Y-%m-%d)

# Timezone for workday calculations
LOCAL_TZ="America/New_York"

# Display Copilot Premium Request Usage
echo -e "\n${GREEN}Copilot Premium Model Requests:${NC}"
echo "  Total Limit:      $LIMIT_REQUESTS requests"
echo "  Remaining:        $REMAINING_REQUESTS requests"
USED_REQUESTS=$((LIMIT_REQUESTS - REMAINING_REQUESTS))
echo "  Used:             $USED_REQUESTS requests"

# Track daily usage (UTC-based day)
USAGE_CACHE_FILE="/tmp/gh-copilot-usage-tracker.txt"
USED_TODAY=0

if [ -f "$USAGE_CACHE_FILE" ]; then
    CACHED_DATE=$(head -n 1 "$USAGE_CACHE_FILE")
    CACHED_REMAINING=$(tail -n 1 "$USAGE_CACHE_FILE")
    
    if [ "$CACHED_DATE" = "$CURRENT_UTC_DATE" ]; then
        # Same day - calculate usage since last check
        USED_TODAY=$((CACHED_REMAINING - REMAINING_REQUESTS))
        if [ $USED_TODAY -lt 0 ]; then
            # Quota may have reset or refreshed
            USED_TODAY=0
        fi
    else
        # New day - reset counter
        USED_TODAY=0
    fi
fi

# If cache didn't capture changes (e.g., this script wasn't run earlier today), try history file as a fallback
HISTORY_FILE="$HOME/.copilot-usage-history.csv"
if [ "$USED_TODAY" -eq 0 ] && [ -f "$HISTORY_FILE" ]; then
    FIRST_USED=$(awk -F, -v d="$CURRENT_UTC_DATE" 'NR>1 && $1 ~ d {print $3; exit}' "$HISTORY_FILE" || echo "")
    LAST_USED=$(awk -F, -v d="$CURRENT_UTC_DATE" 'NR>1 && $1 ~ d {u=$3} END{if(u)print u}' "$HISTORY_FILE" || echo "")
    if [ -n "$FIRST_USED" ] && [ -n "$LAST_USED" ]; then
        USED_TODAY=$((LAST_USED - FIRST_USED))
        if [ $USED_TODAY -lt 0 ]; then
            USED_TODAY=0
        fi
    fi
fi

# Update cache with current data
echo "$CURRENT_UTC_DATE" > "$USAGE_CACHE_FILE"
echo "$REMAINING_REQUESTS" >> "$USAGE_CACHE_FILE"

echo "  Used today (UTC): $USED_TODAY requests"

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
                
                # Calculate recommended percentage left at current time (local timezone)
                CURRENT_HOUR=$(TZ="$LOCAL_TZ" date +%H)
                CURRENT_MINUTE=$(TZ="$LOCAL_TZ" date +%M)
                HOURS_INTO_DAY=$(echo "scale=2; $CURRENT_HOUR + $CURRENT_MINUTE / 60" | bc)
                LOCAL_TIME=$(TZ="$LOCAL_TZ" date "+%H:%M")
                
                # Assume workday starts at 9 AM and ends at 6 PM (9 hours)
                WORKDAY_START=9
                WORKDAY_END=18
                WORKDAY_HOURS=$((WORKDAY_END - WORKDAY_START))
                
                echo ""
                echo -e "  ${CYAN}Today's usage (UTC day):${NC}"
                echo "    Used today: $USED_TODAY requests"
                echo "    Daily budget: $DAILY_BUDGET requests"
                
                REMAINING_TODAY=$((DAILY_BUDGET - USED_TODAY))
                if [ $REMAINING_TODAY -lt 0 ]; then
                    OVER_BUDGET=$((REMAINING_TODAY * -1))
                    echo -e "    Status: ${RED}⚠ Over budget by $OVER_BUDGET requests${NC}"
                elif [ $USED_TODAY -gt $((DAILY_BUDGET * 3 / 4)) ]; then
                    echo -e "    Status: ${YELLOW}⚠ Used ${USED_TODAY}/${DAILY_BUDGET} (approaching limit)${NC}"
                else
                    echo -e "    Status: ${GREEN}✓ Used ${USED_TODAY}/${DAILY_BUDGET}${NC}"
                fi
                
                if (( $(echo "$CURRENT_HOUR >= $WORKDAY_START && $CURRENT_HOUR < $WORKDAY_END" | bc -l) )); then
                    HOURS_INTO_WORKDAY=$(echo "scale=2; $HOURS_INTO_DAY - $WORKDAY_START" | bc)
                    FRACTION_OF_DAY_ELAPSED=$(echo "scale=4; $HOURS_INTO_WORKDAY / $WORKDAY_HOURS" | bc)
                    
                    # Calculate recommended percentage left now
                    RECOMMENDED_REQUESTS_USED=$(echo "scale=2; $DAILY_BUDGET * $FRACTION_OF_DAY_ELAPSED" | bc)
                    RECOMMENDED_REMAINING=$(echo "scale=2; $REMAINING_REQUESTS - $RECOMMENDED_REQUESTS_USED" | bc)
                    RECOMMENDED_PCT_LEFT=$(echo "scale=1; ($RECOMMENDED_REMAINING * 100) / $LIMIT_REQUESTS" | bc)
                    
                    # Calculate recommended percentage left at end of day
                    RECOMMENDED_REMAINING_EOD=$(echo "scale=2; $REMAINING_REQUESTS - $DAILY_BUDGET" | bc)
                    RECOMMENDED_PCT_LEFT_EOD=$(echo "scale=1; ($RECOMMENDED_REMAINING_EOD * 100) / $LIMIT_REQUESTS" | bc)
                    
                    echo ""
                    echo -e "  ${CYAN}Current trajectory ($LOCAL_TZ - ${LOCAL_TIME}):${NC}"
                    # Format recommended remaining requests as integers beside percentages
                    RECOMMENDED_REMAINING_INT=$(printf "%.0f" "$RECOMMENDED_REMAINING")
                    RECOMMENDED_REMAINING_EOD_INT=$(printf "%.0f" "$RECOMMENDED_REMAINING_EOD")
                    # Calculate numeric differences between actual remaining and recommendations
                    DIFF_NOW=$((REMAINING_REQUESTS - RECOMMENDED_REMAINING_INT))
                    # How many requests are still available today to stay on the EOD target
                    AVAILABLE_TODAY=$((DAILY_BUDGET - USED_TODAY))
                    # Raw diff between actual remaining and recommended EOD remaining (for reference)
                    RAW_DIFF_EOD=$((REMAINING_REQUESTS - RECOMMENDED_REMAINING_EOD_INT))
                    echo "    Recommended left at this time: ${RECOMMENDED_PCT_LEFT}% (${RECOMMENDED_REMAINING_INT} requests) (EOD target: ${RECOMMENDED_PCT_LEFT_EOD}% (${RECOMMENDED_REMAINING_EOD_INT} requests))"
                    printf "    Actual remaining: %s (%d requests)\n" "${PERCENT_REMAINING}%" "${REMAINING_REQUESTS}"
                    # Show numeric differences
                    printf "    Difference (now): %+d requests\n" "$DIFF_NOW"
                    printf "    Remaining available today to stay on EOD target: %+d requests\n" "$AVAILABLE_TODAY"
                    printf "    (Raw diff vs EOD recommended remaining: %+d requests)\n" "$RAW_DIFF_EOD"

                    # Show status
                    AHEAD_BEHIND=$(echo "$PERCENT_REMAINING - $RECOMMENDED_PCT_LEFT" | bc)
                    if (( $(echo "$AHEAD_BEHIND > 1" | bc -l) )); then
                        echo -e "    Status: ${GREEN}✓ On track (${AHEAD_BEHIND}% ahead)${NC}"
                    elif (( $(echo "$AHEAD_BEHIND < -1" | bc -l) )); then
                        BEHIND_POSITIVE=$(echo "$AHEAD_BEHIND * -1" | bc)
                        echo -e "    Status: ${YELLOW}⚠ Behind pace (${BEHIND_POSITIVE}% behind)${NC}"
                    else
                        echo -e "    Status: ${GREEN}✓ On track${NC}"
                    fi
                else
                    echo ""
                    echo -e "  ${CYAN}Note: Trajectory tracking is for 9AM-6PM $LOCAL_TZ workday hours${NC}"
                    echo "    Current local time: $LOCAL_TIME"
                fi
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
