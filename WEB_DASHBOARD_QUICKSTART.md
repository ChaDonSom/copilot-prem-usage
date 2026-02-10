# Quick Start: Using the Web Dashboard

## For First-Time Users

### Step 1: Create a GitHub OAuth App

1. Go to https://github.com/settings/developers
2. Click **"New OAuth App"**
3. Fill in these details:
   - **Application name:** `Copilot Usage Tracker` (or any name you prefer)
   - **Homepage URL:** `http://localhost:8000` (for local testing)
   - **Authorization callback URL:** `http://localhost:8000/login/github/callback`
4. Click **"Register application"**
5. You'll see your **Client ID** - copy it
6. Click **"Generate a new client secret"** - copy this too

### Step 2: Configure the Laravel App

1. Open `copilot-tracker/.env` file
2. Add these lines (or update if they exist):
   ```env
   GITHUB_CLIENT_ID=paste_your_client_id_here
   GITHUB_CLIENT_SECRET=paste_your_client_secret_here
   GITHUB_REDIRECT_URL=http://localhost:8000/login/github/callback
   ```
3. Save the file

### Step 3: Start the App

```bash
cd copilot-tracker
php artisan serve
```

You should see: `Laravel development server started: http://127.0.0.1:8000`

### Step 4: Login and View Your Dashboard

1. Open your browser and go to: `http://localhost:8000`
2. Click **"Login with GitHub"**
3. GitHub will ask you to authorize the app - click **"Authorize"**
4. You'll be redirected to your dashboard! 🎉

## What You'll See

### Dashboard Features

- **Usage Statistics Cards:**
  - Total monthly limit (e.g., 1500 requests)
  - Remaining requests with percentage
  - Requests used this month
  - Next reset date

- **Usage Trend Graph:**
  - 30-day historical view
  - Shows daily usage patterns
  - Visual trend of requests used vs. remaining

- **Warnings:**
  - Yellow alert if you've used > 75% of your quota
  - Helps you pace your usage

## For Production Deployment

When deploying to Laravel Cloud or another server:

1. **Update your GitHub OAuth App:**
   - Go back to https://github.com/settings/developers
   - Click on your OAuth app
   - Update these URLs:
     - Homepage URL: `https://your-domain.com`
     - Callback URL: `https://your-domain.com/login/github/callback`
   - Save changes

2. **Update your .env on production:**
   ```env
   APP_URL=https://your-domain.com
   GITHUB_REDIRECT_URL=https://your-domain.com/login/github/callback
   ```

3. **That's it!** The same client ID and secret work for both local and production.

## Troubleshooting

### "Application credentials not configured"
- Check that `GITHUB_CLIENT_ID` and `GITHUB_CLIENT_SECRET` are set in `.env`
- Make sure you've restarted `php artisan serve` after editing `.env`

### "Invalid redirect_uri"
- The callback URL in your GitHub OAuth app must EXACTLY match what's in your `.env`
- Check for `http` vs `https` mismatch
- Check for trailing slashes

### "No usage data"
- This is normal for first-time login
- The app will fetch your usage from GitHub automatically
- Refresh the page after a few seconds

### Dashboard shows empty graph
- You need at least 2 usage snapshots for a trend
- Check back after using Copilot and running the bash script a few times
- Or wait for the hourly scheduler to collect data

## Privacy & Security

- Your GitHub token is encrypted in the database
- Only you can see your usage data
- The app only requests minimal GitHub permissions (`read:user`)
- No data is shared with third parties

## Need Help?

- Check the full README: `copilot-tracker/README.md`
- See OAuth setup details: `copilot-tracker/OAUTH_SETUP.md`
- Review debugging guide: `DEBUGGING_GUIDE.md`
