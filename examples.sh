#!/bin/bash
# Example usage of check-copilot-usage.sh and track-usage.sh

echo "==================================================================="
echo "Example 1: Check current usage (automatic via API)"
echo "==================================================================="
echo "Run: ./check-copilot-usage.sh"
echo ""
./check-copilot-usage.sh

echo ""
echo ""
echo "==================================================================="
echo "Example 2: Track usage history"
echo "==================================================================="
echo "Run: ./track-usage.sh"
echo ""
./track-usage.sh

echo ""
echo ""
echo "==================================================================="
echo "Example 3: Check just the raw API data"
echo "==================================================================="
echo "Run: gh api /copilot_internal/user | jq '.quota_snapshots.premium_interactions'"
echo ""
gh api /copilot_internal/user | jq '.quota_snapshots.premium_interactions'

echo ""
echo ""
echo "==================================================================="
echo "Example 4: Quick one-liner to see remaining requests"
echo "==================================================================="
echo "Run: gh api /copilot_internal/user | jq -r '.quota_snapshots.premium_interactions.remaining'"
echo ""
gh api /copilot_internal/user | jq -r '.quota_snapshots.premium_interactions.remaining'
echo " requests remaining"

echo ""

