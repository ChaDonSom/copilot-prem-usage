# GitHub Copilot Internal API Documentation

## Discovery

This API endpoint was discovered by analyzing the [copilot-api](https://github.com/caozhiyuan/copilot-api) npm package, which reverse-engineered the calls made by VS Code's Copilot extension.

## Endpoint

```
GET https://api.github.com/copilot_internal/user
```

## Authentication

Requires a GitHub Personal Access Token with Copilot access.

Using GitHub CLI:
```bash
gh api /copilot_internal/user
```

Using curl:
```bash
curl -H "Authorization: Bearer $(gh auth token)" \
     https://api.github.com/copilot_internal/user
```

## Response Structure

```json
{
  "login": "username",
  "access_type_sku": "plus_monthly_subscriber_quota",
  "analytics_tracking_id": "...",
  "assigned_date": "2026-01-30T10:00:46-05:00",
  "can_signup_for_limited": false,
  "chat_enabled": true,
  "copilot_plan": "individual_pro",
  "organization_login_list": [],
  "organization_list": [],
  "endpoints": {
    "api": "https://api.individual.githubcopilot.com",
    "origin-tracker": "https://origin-tracker.individual.githubcopilot.com",
    "proxy": "https://proxy.individual.githubcopilot.com",
    "telemetry": "https://telemetry.individual.githubcopilot.com"
  },
  "codex_agent_enabled": true,
  "quota_reset_date": "2026-03-01",
  "quota_snapshots": {
    "chat": {
      "entitlement": 0,
      "overage_count": 0,
      "overage_permitted": false,
      "percent_remaining": 100,
      "quota_id": "chat",
      "quota_remaining": 0,
      "remaining": 0,
      "unlimited": true,
      "timestamp_utc": "2026-02-10T13:40:44.935Z"
    },
    "completions": {
      "entitlement": 0,
      "overage_count": 0,
      "overage_permitted": false,
      "percent_remaining": 100,
      "quota_id": "completions",
      "quota_remaining": 0,
      "remaining": 0,
      "unlimited": true,
      "timestamp_utc": "2026-02-10T13:40:44.935Z"
    },
    "premium_interactions": {
      "entitlement": 1500,
      "overage_count": 0,
      "overage_permitted": true,
      "percent_remaining": 70.28,
      "quota_id": "premium_interactions",
      "quota_remaining": 1054.25,
      "remaining": 1054,
      "unlimited": false,
      "timestamp_utc": "2026-02-10T13:40:44.935Z"
    }
  },
  "quota_reset_date_utc": "2026-03-01T00:00:00.000Z"
}
```

## Key Fields

### User Info
- `login`: GitHub username
- `copilot_plan`: Plan type (e.g., "individual_pro", "business", "enterprise")
- `assigned_date`: When Copilot was activated
- `chat_enabled`: Whether Copilot Chat is enabled

### Quota Snapshots

Each quota type has these fields:

- `entitlement`: Total quota (monthly limit)
- `remaining`: Requests remaining this period
- `quota_remaining`: Same as remaining (with decimals)
- `percent_remaining`: Percentage of quota left
- `overage_count`: Requests used beyond quota
- `overage_permitted`: Whether overages are allowed
- `unlimited`: Whether this quota is unlimited
- `timestamp_utc`: When this snapshot was taken

### Quota Types

1. **premium_interactions**: Advanced model requests (GPT-4, Claude, etc.)
   - Limited (e.g., 1500/month for Pro)
   - This is what matters for premium usage tracking

2. **chat**: Copilot Chat requests
   - Usually unlimited for paid plans

3. **completions**: Code completion requests
   - Usually unlimited for paid plans

### Reset Schedule

- `quota_reset_date`: Date when quota resets (YYYY-MM-DD format)
- `quota_reset_date_utc`: Same in ISO 8601 UTC format
- Resets monthly on the 1st at 00:00:00 UTC

## Usage Examples

### Get remaining premium requests
```bash
gh api /copilot_internal/user | jq -r '.quota_snapshots.premium_interactions.remaining'
```

### Get quota reset date
```bash
gh api /copilot_internal/user | jq -r '.quota_reset_date'
```

### Get full premium quota info
```bash
gh api /copilot_internal/user | jq '.quota_snapshots.premium_interactions'
```

### Check if quota is unlimited
```bash
gh api /copilot_internal/user | jq -r '.quota_snapshots.premium_interactions.unlimited'
```

### Get plan type
```bash
gh api /copilot_internal/user | jq -r '.copilot_plan'
```

## Plan Types and Limits

Different Copilot plans have different entitlements:

| Plan | Premium Interactions/Month |
|------|---------------------------|
| Individual | 500 |
| Individual Pro | 1500 |
| Business | Varies by org |
| Enterprise | Higher limits |

## Notes

- **This is an internal/undocumented API**
  - May change without notice
  - Not officially supported by GitHub
  - Use at your own risk

- **Rate limiting**
  - Subject to standard GitHub API rate limits
  - No known specific limits for this endpoint

- **Permissions**
  - Requires authenticated user with Copilot access
  - Read-only (no mutations possible)

- **Refresh rate**
  - Data appears to be real-time or near real-time
  - Updated immediately after Copilot usage

## Alternative Methods

If this API endpoint stops working:

1. **IDE Status Bar**: Check VS Code/JetBrains Copilot icon
2. **Web UI**: https://github.com/settings/billing
3. **Organization API**: For org admins, use official `/orgs/{org}/copilot/metrics` endpoint

## Credits

- Discovered via [copilot-api](https://github.com/caozhiyuan/copilot-api) npm package
- Reverse-engineered from VS Code Copilot extension behavior
