# Debugging Empty Response from Laravel Cloud

## What Was Happening

Your script was getting empty output because:
1. The Laravel server was returning HTTP 500 (Server Error)
2. The `curl` command with `-sf` flag fails silently on server errors
3. No error message was displayed

## What I Fixed

### 1. Script Improvements
- Updated error handling to show HTTP status codes
- Added error message display from server responses
- Now you'll see: `Server error (HTTP 500): [error message]`

### 2. Laravel Application Improvements
- Added try-catch blocks in middleware and service
- Added detailed error logging for:
  - Encryption errors (missing/wrong APP_KEY)
  - Database connection errors
  - GitHub API errors
- Error messages now include specific details about what went wrong

## Current Status

The script now shows:
```
Server error (HTTP 500):
Server Error
```

The generic "Server Error" message means Laravel is hiding the actual error details (production mode).

## Most Likely Causes (in order)

### 1. ❗ Missing or Invalid APP_KEY (MOST LIKELY)
Laravel uses encryption to store GitHub tokens. Without a valid `APP_KEY`, encryption fails.

**To Fix:**
```bash
# Generate a new key locally
cd copilot-tracker
php artisan key:generate --show
```

Then in Laravel Cloud:
- Go to your deployment settings
- Add/update environment variable: `APP_KEY=base64:YOUR_GENERATED_KEY`
- Redeploy

### 2. Database Not Set Up
Tables need to be created via migrations.

**To Check:**
In Laravel Cloud console, run:
```bash
php artisan migrate:status
```

**To Fix:**
```bash
php artisan migrate --force
```

### 3. Wrong Database Configuration
Ensure these are set in Laravel Cloud environment:
- `DB_CONNECTION=sqlite` (or mysql, pgsql)
- `DB_DATABASE=/path/to/database.sqlite` (for SQLite)

## How to Debug Further

### Option 1: Check Laravel Logs
In Laravel Cloud dashboard:
1. Go to your deployment
2. Click "Logs"
3. Look for error messages with keywords:
   - `DecryptException`
   - `Encryption error`
   - `database`
   - `migration`

### Option 2: Temporarily Enable Debug Mode
⚠️ **Only for debugging, disable after!**

In Laravel Cloud environment variables:
```
APP_DEBUG=true
```

Then run the script again. You'll see detailed error stack traces.

**Remember to set back to `false` when done!**

### Option 3: Test Locally
```bash
cd copilot-tracker
php artisan serve
```

In another terminal:
```bash
GITHUB_TOKEN=$(gh auth token)
curl -i -H "Authorization: Bearer $GITHUB_TOKEN" \
  http://localhost:8000/api/usage
```

If this works locally but not on Laravel Cloud, it's an environment configuration issue.

## Deployment Steps

1. **Commit and push the updated code:**
   ```bash
   git add copilot-tracker/app/Http/Middleware/GitHubTokenAuth.php
   git add copilot-tracker/app/Services/GitHubCopilotService.php
   git add check-copilot-usage.sh
   git commit -m "Add better error handling and logging"
   git push
   ```

2. **Ensure APP_KEY is set** in Laravel Cloud

3. **Check database** is configured and migrated

4. **Check logs** in Laravel Cloud dashboard

5. **Test again:**
   ```bash
   ./check-copilot-usage.sh --force-refresh
   ```

## Quick Test Commands

```bash
# Test health endpoint
curl https://copilot-tracker-master-qpfpif.laravel.cloud/health

# Test API with debug info
GITHUB_TOKEN=$(gh auth token)
curl -i -H "Authorization: Bearer $GITHUB_TOKEN" \
  https://copilot-tracker-master-qpfpif.laravel.cloud/api/usage
```

## What to Look For

✅ **Success Response (HTTP 200):**
```json
{
  "username": "ChaDonSom",
  "copilot_plan": "individual_pro",
  "usage": {
    "quota_limit": 1500,
    "remaining": 1032,
    ...
  }
}
```

❌ **Auth Error (HTTP 401):**
```json
{
  "error": "Invalid GitHub token",
  "message": "..."
}
```

❌ **Server Error (HTTP 500):**
```json
{
  "error": "Authentication failed",
  "message": "An error occurred during authentication: ..."
}
```

## Next Steps

1. Deploy the updated code to Laravel Cloud (commit and push)
2. Set the `APP_KEY` environment variable
3. Check/run database migrations
4. Check the Laravel logs for specific error details
5. Test with the script again

The improved error handling will now show you exactly what's wrong!
