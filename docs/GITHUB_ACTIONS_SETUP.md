# GitHub Actions Auto-Scraper Setup Guide

## Schedule

- **1st of every month at 8:00 UTC**
- Can also be triggered manually at any time

## Setup Steps

### Step 1: Get Firebase Service Account

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your CardWise project
3. Click **Project Settings** > **Service accounts**
4. Click **Generate new private key**
5. Download the JSON file

### Step 2: Add GitHub Secret

1. Go to your GitHub Repo: https://github.com/YOUR_USERNAME/CardWise
2. Click **Settings** > **Secrets and variables** > **Actions**
3. Click **New repository secret**
4. Name: `FIREBASE_SERVICE_ACCOUNT`
5. Value: Paste the entire JSON file content
6. Click **Add secret**

### Step 3: Push the Code

```bash
git add .github/workflows/monthly-scraper.yml
git commit -m "feat: add monthly auto scraper via GitHub Actions"
git push
```

### Step 4: Test

1. Go to GitHub Repo > **Actions**
2. Click **Monthly Credit Card Scraper**
3. Click **Run workflow** > **Run workflow**
4. Wait for completion (approximately 2-3 minutes)

## Results

After each run, you can see the following on the Actions page:
- Number of cards scraped
- Number of cards with images
- Upload time to Firestore

## Changing the Schedule

Edit `.github/workflows/monthly-scraper.yml`:

```yaml
on:
  schedule:
    # 1st of every month
    - cron: '0 8 1 * *'

    # Or change to every Monday
    # - cron: '0 8 * * 1'

    # Or change to daily
    # - cron: '0 8 * * *'
```

Cron format: `minute hour day month weekday`

## Cost

- GitHub Actions private repos: 2000 free minutes per month
- Each scraper run takes approximately 2-3 minutes
- Once per month = approximately 3 minutes, well within free tier

## Security Recommendations

### Workload Identity Federation (Recommended)

Instead of storing a long-lived service account JSON key as a GitHub secret, consider using **Workload Identity Federation** for keyless authentication:

1. Create a Workload Identity Pool in Google Cloud:
   ```bash
   gcloud iam workload-identity-pools create "github-pool" \
     --location="global" \
     --display-name="GitHub Actions Pool"
   ```

2. Create a provider for GitHub:
   ```bash
   gcloud iam workload-identity-pools providers create-oidc "github-provider" \
     --location="global" \
     --workload-identity-pool="github-pool" \
     --display-name="GitHub Provider" \
     --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
     --issuer-uri="https://token.actions.githubusercontent.com"
   ```

3. Grant the service account permissions to the pool, then use `google-github-actions/auth@v2` in your workflow.

This eliminates the need for rotating service account keys.

### Key Rotation Reminder

If you continue using a service account JSON key:

- **Rotate the key at least every 90 days**
- Go to Firebase Console > Project Settings > Service Accounts
- Generate a new private key, update the `FIREBASE_SERVICE_ACCOUNT` GitHub secret
- Delete the old key from Google Cloud Console > IAM > Service Accounts > Keys
- Consider setting a calendar reminder for periodic rotation

### Additional Hardening

- Restrict the service account to the minimum required permissions (Firestore write only)
- Enable GitHub's secret scanning to detect accidental exposure
- Review Actions audit logs periodically for unauthorized workflow runs

## Troubleshooting

### Run Failed

1. Check error messages on the Actions page
2. Verify the `FIREBASE_SERVICE_ACCOUNT` secret is set correctly
3. Ensure the JSON format is correct (no extra spaces or line breaks)

### Manual Trigger

If the scheduled run isn't working, you can trigger it manually at any time:
1. Go to the Actions page
2. Click **Monthly Credit Card Scraper**
3. Click **Run workflow**
