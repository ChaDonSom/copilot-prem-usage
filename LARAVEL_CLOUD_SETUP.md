# Laravel Cloud Setup Guide

## Common Issues and Solutions

### 500 Server Error (Empty Response)

If you're getting empty responses from the server, the most common causes are:

#### 1. Missing or Invalid APP_KEY

The application uses Laravel's encryption for storing GitHub tokens. This requires a valid `APP_KEY`.

**To Fix:**
1. Go to your Laravel Cloud dashboard
2. Navigate to your deployment's Environment Variables
3. Ensure `APP_KEY` is set to a valid Laravel key (starts with `base64:`)
4. If missing, generate one locally: `php artisan key:generate --show`
5. Copy the generated key and add it to Laravel Cloud environment variables

#### 2. Database Not Migrated

The application requires database tables to be created.

**To Fix:**
1. In Laravel Cloud, ensure migrations are run during deployment
2. Or manually run: `php artisan migrate --force` in the Laravel Cloud console

#### 3. Missing Database Connection

Ensure these environment variables are set in Laravel Cloud:
- `DB_CONNECTION` (e.g., `sqlite`, `mysql`, `pgsql`)
- `DB_DATABASE` (database name or path for SQLite)
- For MySQL/PostgreSQL:
  - `DB_HOST`
  - `DB_PORT`
  - `DB_USERNAME`
  - `DB_PASSWORD`

## Testing the Deployment

### 1. Check Health Endpoint
```bash
curl https://copilot-tracker-master-qpfpif.laravel.cloud/health
```
Expected: `{"status":"ok","timestamp":"..."}`

### 2. Test API with Auth
```bash
GITHUB_TOKEN=$(gh auth token)
curl -i -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/json" \
  https://copilot-tracker-master-qpfpif.laravel.cloud/api/usage
```

Expected (Success): HTTP 200 with usage data
Expected (Error): HTTP 500 with error details (now shows specific error message)

## Checking Laravel Logs

In Laravel Cloud dashboard:
1. Go to your deployment
2. Check "Logs" section
3. Look for errors related to:
   - `Encryption error`
   - `DecryptException`
   - Database connection errors
   - Migration errors

## Quick Deployment Checklist

- [ ] `APP_KEY` is set
- [ ] `APP_ENV` is set (e.g., `production`)
- [ ] `APP_DEBUG` is `false` for production
- [ ] Database connection is configured
- [ ] Migrations have been run
- [ ] Storage directories are writable

## Environment Variables Template

```env
APP_NAME="Copilot Tracker"
APP_ENV=production
APP_KEY=base64:YOUR_KEY_HERE
APP_DEBUG=false
APP_TIMEZONE=UTC
APP_URL=https://copilot-tracker-master-qpfpif.laravel.cloud

DB_CONNECTION=sqlite
DB_DATABASE=/path/to/database.sqlite

LOG_CHANNEL=stack
LOG_LEVEL=info
```

## Next Steps

1. Deploy the updated code with better error handling
2. Check the Laravel Cloud logs for specific error messages
3. Fix any missing environment variables
4. Run migrations if needed
5. Test again with the script
