# Quick Start Guide

## TL;DR

**We found the API!** This script automatically fetches your Copilot Premium usage from GitHub's internal API.

## One-Command Usage

```bash
./check-copilot-usage.sh
```

That's it! No manual input needed.

## What You Get

Instantly see:
- ✅ Total monthly premium request limit
- ✅ Requests used this month
- ✅ Requests remaining
- ✅ Daily budget recommendation
- ✅ Hourly usage patterns
- ✅ Reset date

## Example Output

```
=== GitHub Copilot Premium Request Usage ===

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

## Track Usage Over Time

Want to track your usage history?

```bash
./track-usage.sh
```

This will:
- Automatically fetch current usage
- Append to `~/.copilot-usage-history.csv`
- Show usage trends and rate of consumption
- Detect monthly resets

Run it daily or weekly to build a history!

## The Secret Sauce

This script uses GitHub's **undocumented** internal API:
```
GET /copilot_internal/user
```

Accessible via the `gh` CLI with your normal GitHub token.

## Setup (First Time)

1. Install dependencies:
```bash
sudo apt-get install -y jq bc
```

2. Make scripts executable:
```bash
chmod +x check-copilot-usage.sh track-usage.sh
```

3. Run:
```bash
./check-copilot-usage.sh
```

## Pro Tips

- 💡 Run `./track-usage.sh` daily to monitor trends
- 💡 Set up a cron job for automatic tracking
- 💡 Premium requests = advanced models (GPT-4, Claude, etc.)
- 💡 Basic code completions are UNLIMITED (don't count)
- 💡 Quota resets on the 1st of each month at 00:00 UTC

## Cron Job (Optional)

Track usage automatically every day at 9 AM:

```bash
# Edit crontab
crontab -e

# Add this line:
0 9 * * * /path/to/copilot-prem-usage/track-usage.sh >> /tmp/copilot-tracker.log 2>&1
```

## Troubleshooting

### "Not Found" error?
- Make sure you have an active Copilot subscription
- Run: `gh auth login` to re-authenticate

### Want more details?
See the full [README.md](README.md) for technical details and API documentation.
