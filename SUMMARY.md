# Summary: GitHub Copilot Premium Usage Tracker

## What We Built

A complete toolkit for tracking GitHub Copilot Premium request usage via the **undocumented internal API**.

## The Discovery 🔍

Found the API endpoint that VS Code and other Copilot clients use:
```
GET /copilot_internal/user
```

This endpoint returns **real-time** premium request usage without any manual input!

## Files Created

### 1. `check-copilot-usage.sh` - Main Usage Checker
**Purpose**: Check your current Copilot premium usage  
**Usage**: `./check-copilot-usage.sh`  
**Output**: 
- Premium requests used/remaining
- Daily budget recommendations
- Hourly usage patterns
- Warnings if running low

### 2. `track-usage.sh` - Historical Tracker
**Purpose**: Track usage over time  
**Usage**: `./track-usage.sh`  
**Features**:
- Automatically fetches current usage
- Appends to `~/.copilot-usage-history.csv`
- Shows trends and consumption rate
- Detects monthly resets

### 3. `examples.sh` - Usage Examples
**Purpose**: Demonstrate all features  
**Usage**: `./examples.sh`  
**Shows**: Various ways to query the API

### 4. `README.md` - Full Documentation
Complete guide with:
- Feature overview
- Installation instructions
- API details
- Troubleshooting

### 5. `QUICKSTART.md` - Quick Reference
TL;DR version for fast setup

### 6. `API.md` - API Documentation
Detailed API endpoint documentation including:
- Request/response format
- Field descriptions
- Usage examples
- Plan limits

## Key Features ✨

- ✅ **Fully Automated**: No manual input needed
- ✅ **Real-time Data**: Direct from GitHub's API
- ✅ **Smart Recommendations**: Daily/hourly usage budgets
- ✅ **Historical Tracking**: CSV export for trend analysis
- ✅ **Color-Coded Warnings**: Visual alerts when running low
- ✅ **Multiple Interfaces**: CLI scripts + raw API access

## Usage Examples

### Quick Check
```bash
./check-copilot-usage.sh
```

### Track History
```bash
./track-usage.sh
```

### One-Liner
```bash
gh api /copilot_internal/user | jq -r '.quota_snapshots.premium_interactions.remaining'
```

## The API Endpoint

```bash
gh api /copilot_internal/user
```

Returns:
- `entitlement`: Monthly limit (e.g., 1500 for Pro)
- `remaining`: Requests left this month  
- `percent_remaining`: Usage percentage
- `quota_reset_date`: When quota resets
- `copilot_plan`: Your plan type

## Real Output Example

```
User: ChaDonSom
Plan: individual_pro

Copilot Premium Model Requests:
  Total Limit:      1500 requests
  Remaining:        1054 requests
  Used:             446 requests
  Usage:            29.7%
  Resets at:        2026-03-01 00:00:00
  Time until reset: 18.6 days

=== Daily Usage Recommendations ===
  Recommended daily budget: 58 requests/day
  (Based on 1054 requests over 18 days)

  Usage patterns:
    Conservative (12h/day): ~4.8 requests/hour
    Moderate (10h/day):     ~5.8 requests/hour
    Focused (8h/day):       ~7.2 requests/hour
```

## Automation Ideas 🤖

### Daily Tracking Cron Job
```bash
# Run every day at 9 AM
0 9 * * * /path/to/track-usage.sh >> /tmp/copilot.log 2>&1
```

### Alert When Low
```bash
# Alert at 25% remaining
REMAINING=$(gh api /copilot_internal/user | jq -r '.quota_snapshots.premium_interactions.remaining')
if [ $REMAINING -lt 375 ]; then
    echo "⚠️  Low on Copilot requests: $REMAINING left" | mail -s "Copilot Alert" you@email.com
fi
```

### Integration with Monitoring
Export to Prometheus, Grafana, etc. by parsing the CSV history file.

## What This Solves

Before:
- ❌ Had to manually check GitHub web UI
- ❌ No way to track usage programmatically
- ❌ No historical data
- ❌ No automated alerts

After:
- ✅ Automated API access
- ✅ Command-line interface
- ✅ Historical tracking with CSV export
- ✅ Smart recommendations
- ✅ Easy to integrate with other tools

## Technical Notes

- **Undocumented API**: May change without notice
- **No rate limiting observed**: Safe to query frequently
- **Real-time data**: Updates immediately after usage
- **Read-only**: No way to modify quota via API

## Credits

- Inspired by [copilot-api](https://github.com/caozhiyuan/copilot-api) npm package
- Endpoint discovered by reverse-engineering VS Code extension
- Built with `gh` CLI, `jq`, and `bc`
