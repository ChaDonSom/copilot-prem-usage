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

#### 2. Database Not Migrated or Not Set Up

The application requires:
1. A PostgreSQL database (Laravel Cloud doesn't support SQLite)
2. Database tables created via migrations

**To Fix:**

First, ensure you have a PostgreSQL database provisioned in Laravel Cloud:
1. Go to your Laravel Cloud project dashboard
2. Navigate to "Databases" section
3. Create a new PostgreSQL database (free tier available)
4. Note the connection details provided

Then set the environment variables and run migrations:
1. Add database environment variables (see Environment Variables section below)
2. In Laravel Cloud console, run: `php artisan migrate --force`

Or ensure migrations are set to run automatically during deployment.

#### 3. PostgreSQL Database Not Configured

**IMPORTANT:** Laravel Cloud only supports PostgreSQL databases (and Redis/Valkey for caching).  
SQLite is NOT supported in production.

Ensure these environment variables are set in Laravel Cloud:
- `DB_CONNECTION=pgsql` (required for production)
- `DB_HOST` (provided by Laravel Cloud when you create a database)
- `DB_PORT=5432` (default PostgreSQL port)
- `DB_DATABASE` (your database name)
- `DB_USERNAME` (provided by Laravel Cloud)
- `DB_PASSWORD` (provided by Laravel Cloud)

**Steps to set up:**
1. In Laravel Cloud dashboard, go to "Databases"
2. Create a new PostgreSQL database (free tier: $0 for no usage)
3. Copy the connection details
4. Add them to your environment variables
5. Run migrations: `php artisan migrate --force`

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

- [ ] PostgreSQL database created in Laravel Cloud
- [ ] `APP_KEY` is set (generate with `php artisan key:generate --show`)
- [ ] `APP_ENV=production`
- [ ] `APP_DEBUG=false` for production
- [ ] Database connection configured (`DB_CONNECTION=pgsql`)
- [ ] All PostgreSQL credentials set (`DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`)
- [ ] Migrations have been run (`php artisan migrate --force`)
- [ ] Storage directories are writable

## Environment Variables Template

**For Laravel Cloud (Production):**

```env
APP_NAME="Copilot Tracker"
APP_ENV=production
APP_KEY=base64:YOUR_KEY_HERE
APP_DEBUG=false
APP_TIMEZONE=UTC
APP_URL=https://copilot-tracker-master-qpfpif.laravel.cloud

# PostgreSQL Database (Required for Laravel Cloud)
DB_CONNECTION=pgsql
DB_HOST=your-postgres-host.laravel.cloud
DB_PORT=5432
DB_DATABASE=your-database-name
DB_USERNAME=your-username
DB_PASSWORD=your-password

LOG_CHANNEL=stack
LOG_LEVEL=info
```

**For Local Development:**

```env
APP_NAME="Copilot Tracker"
APP_ENV=local
APP_KEY=base64:YOUR_KEY_HERE
APP_DEBUG=true
APP_URL=http://localhost

# SQLite for local (easy setup)
DB_CONNECTION=sqlite
# DB_DATABASE will default to database/database.sqlite

LOG_CHANNEL=stack
LOG_LEVEL=debug
```

## Next Steps

1. Deploy the updated code with better error handling
2. Check the Laravel Cloud logs for specific error messages
3. Fix any missing environment variables
4. Run migrations if needed
5. Test again with the script
