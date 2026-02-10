# GitHub Copilot Premium Usage Checker

A bash script to check your GitHub Copilot Premium request usage **via API** and calculate daily recommendations to stay within your limits.

## 🎉 Features

- ✅ **Fetches usage directly from GitHub's internal API**
- ✅ Real-time premium request quota (no manual input needed!)
- ✅ Calculates daily budget based on remaining requests
- ✅ Provides hourly usage recommendations
- ✅ Color-coded warnings when running low
- ✅ Historical tracking (optional)

## The Discovery

This script uses the **undocumented** GitHub Copilot internal API endpoint:
```
GET https://api.github.com/copilot_internal/user
```

This endpoint returns:
- Premium request limit (e.g., 1500/month for Pro)
- Remaining requests
- Usage percentage
- Reset date
- Plan type

## Requirements

- `gh` (GitHub CLI) - [Install from here](https://cli.github.com/)
- `jq` - JSON parser
- `bc` - Calculator for bash

## Installation

1. Install dependencies:
```bash
# Install jq and bc
sudo apt-get install -y jq bc

# Install GitHub CLI if needed
# Visit: https://cli.github.com/
```

2. Authenticate with GitHub:
```bash
gh auth login
```

3. Make the script executable:
```bash
chmod +x check-copilot-usage.sh
```

## Usage

Simply run the script - no input needed!

```bash
./check-copilot-usage.sh
```

### Example Output

```
=== GitHub Copilot Premium Request Usage ===

Fetching Copilot usage data...
User: YourUsername
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

## Understanding the Output

- **Total Limit**: Your monthly premium request quota
- **Remaining**: Requests left until reset
- **Used**: Requests consumed this month
- **Daily budget**: Recommended requests per day to stay within limit
- **Usage patterns**: 
  - **Conservative (12h/day)**: Spread usage over a long workday
  - **Moderate (10h/day)**: Standard workday usage
  - **Focused (8h/day)**: Concentrated work sessions

## Warnings

The script warns you when:
- ⚠️ **Yellow**: Less than 50% of monthly limit remaining
- ⚠️ **Red**: Less than 25% of monthly limit remaining

## Tracking History

The script saves each check to `/tmp/gh-copilot-usage.json` for debugging.

To track usage over time, run the script periodically and save output:
```bash
./check-copilot-usage.sh >> copilot-usage.log
```

Or use the included tracker script (see `track-usage.sh` if created).

## API Endpoint Details

### Endpoint
```
GET /copilot_internal/user
```

### Authentication
Uses your GitHub CLI token (via `gh auth token`)

### Response Structure
```json
{
  "login": "username",
  "copilot_plan": "individual_pro",
  "quota_reset_date": "2026-03-01",
  "quota_snapshots": {
    "premium_interactions": {
      "entitlement": 1500,
      "remaining": 1054,
      "percent_remaining": 70.28,
      "unlimited": false
    },
    "chat": {
      "unlimited": true,
      ...
    },
    "completions": {
      "unlimited": true,
      ...
    }
  }
}
```

## What Are Premium Requests?

Premium requests are advanced Copilot features using powerful models (GPT-4, Claude 3.5 Sonnet, etc.):

- GitHub Copilot Chat with premium models
- Code explanations with advanced models
- Copilot CLI
- GitHub Copilot Workspace
- Code reviews and complex refactoring

**Note**: Basic code completions are unlimited and don't count against your quota.

## Reset Schedule

Premium request quotas reset:
- **Monthly**: On the 1st of each month at 00:00:00 UTC

## Troubleshooting

### "Not Found" or "Forbidden" Error

This usually means:
1. You don't have an active Copilot subscription
2. Your GitHub CLI token doesn't have the right permissions
3. The API endpoint changed (unlikely)

**Solutions**:
- Verify your subscription: https://github.com/settings/copilot
- Re-authenticate: `gh auth login`
- Check your plan includes premium requests

### Different Quota Than Expected

Different Copilot plans have different limits:
- **Individual**: 500 requests/month
- **Individual Pro**: 1500 requests/month
- **Business**: Varies by organization
- **Enterprise**: Higher limits

## Notes

- This uses an **internal/undocumented** GitHub API endpoint
- The endpoint may change without notice (though unlikely)
- The script is read-only and makes no changes to your account
- Usage data is refreshed in real-time when you run the script

## License

MIT - Use freely!

## Credits

Inspired by the [copilot-api](https://github.com/caozhiyuan/copilot-api) project which discovered this endpoint.
