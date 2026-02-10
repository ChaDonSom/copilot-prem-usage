#!/bin/bash

# Track Copilot usage history over time
# Automatically fetches usage and appends to history file

set -e

HISTORY_FILE="$HOME/.copilot-usage-history.csv"

# Create file with headers if it doesn't exist
if [ ! -f "$HISTORY_FILE" ]; then
    echo "timestamp,limit,used,remaining,percent_used,days_until_reset,plan" > "$HISTORY_FILE"
    echo "✓ Created tracking file: $HISTORY_FILE"
fi

# Fetch current usage
if ! command -v gh &> /dev/null || ! gh auth status &> /dev/null 2>&1; then
    echo "Error: gh CLI not found or not authenticated"
    exit 1
fi

USAGE_DATA=$(gh api /copilot_internal/user 2>&1)

if echo "$USAGE_DATA" | grep -q "Not Found\|Forbidden"; then
    echo "Error: Unable to access Copilot usage API"
    exit 1
fi

# Extract data
LIMIT=$(echo "$USAGE_DATA" | jq -r '.quota_snapshots.premium_interactions.entitlement // 0')
REMAINING=$(echo "$USAGE_DATA" | jq -r '.quota_snapshots.premium_interactions.remaining // 0')
PLAN=$(echo "$USAGE_DATA" | jq -r '.copilot_plan')
RESET_DATE=$(echo "$USAGE_DATA" | jq -r '.quota_reset_date')

USED=$((LIMIT - REMAINING))
PERCENT_USED=$(echo "scale=1; ($USED * 100) / $LIMIT" | bc)

# Calculate days until reset
RESET_TIMESTAMP=$(date -d "$RESET_DATE" +%s 2>/dev/null || echo 0)
CURRENT_TIMESTAMP=$(date +%s)
DAYS_UNTIL_RESET=$(echo "scale=1; ($RESET_TIMESTAMP - $CURRENT_TIMESTAMP) / 86400" | bc)

# Record current usage
TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S")
echo "$TIMESTAMP,$LIMIT,$USED,$REMAINING,$PERCENT_USED,$DAYS_UNTIL_RESET,$PLAN" >> "$HISTORY_FILE"

echo "✓ Usage recorded!"
echo ""
echo "Current status:"
echo "  Limit:     $LIMIT"
echo "  Used:      $USED ($PERCENT_USED%)"
echo "  Remaining: $REMAINING"
echo "  Resets in: $DAYS_UNTIL_RESET days"
echo ""

# Show recent history
echo "Recent history (last 10 checks):"
echo "----------------------------------------"
tail -n 11 "$HISTORY_FILE" | column -t -s','
echo ""

# Calculate trend if we have previous data
LINE_COUNT=$(wc -l < "$HISTORY_FILE")
if [ "$LINE_COUNT" -gt 2 ]; then
    PREV_USED=$(tail -n 2 "$HISTORY_FILE" | head -n 1 | cut -d',' -f3)
    PREV_TIMESTAMP=$(tail -n 2 "$HISTORY_FILE" | head -n 1 | cut -d',' -f1)
    
    CHANGE=$((USED - PREV_USED))
    
    if [ "$CHANGE" -gt 0 ]; then
        echo "📈 Used $CHANGE requests since last check ($PREV_TIMESTAMP)"
        
        # Calculate rate if checks are recent enough
        PREV_TIME=$(date -d "$PREV_TIMESTAMP" +%s 2>/dev/null || echo 0)
        if [ "$PREV_TIME" -gt 0 ]; then
            TIME_DIFF=$((CURRENT_TIMESTAMP - PREV_TIME))
            HOURS_DIFF=$(echo "scale=1; $TIME_DIFF / 3600" | bc)
            if (( $(echo "$HOURS_DIFF > 0 && $HOURS_DIFF < 48" | bc -l) )); then
                RATE=$(echo "scale=1; $CHANGE / $HOURS_DIFF" | bc)
                echo "   Rate: $RATE requests/hour"
            fi
        fi
    elif [ "$CHANGE" -lt 0 ]; then
        echo "🔄 Monthly reset detected (quota refreshed)"
    else
        echo "→ No change since last check"
    fi
fi

echo ""
echo "History file: $HISTORY_FILE"
