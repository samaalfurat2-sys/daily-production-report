# Railway Deployment Guide

## Deploy in 5 Minutes (Free)

### Step 1 — Create Railway Account
Go to [railway.app](https://railway.app) → Sign in with GitHub

### Step 2 — New Project from GitHub
1. Click **"New Project"**
2. Select **"Deploy from GitHub repo"**
3. Choose **`daily-production-report`**
4. Railway auto-detects Python and starts building

### Step 3 — Set Environment Variables
In Railway dashboard → Your service → **Variables** tab, add:

| Variable | Value |
|----------|-------|
| `JWT_SECRET` | any 64-character random string |
| `SEED_DEMO` | `true` |
| `CORS_ORIGINS` | `*` |
| `SHIFT_ORDER` | `A,B,C` |

> Railway automatically provides `DATABASE_URL` (PostgreSQL) or you can leave it
> as SQLite (default). SQLite is fine for small teams.

### Step 4 — Get Your App URL
After deployment (2–3 min), Railway shows:
```
https://daily-production-report-production.up.railway.app
```
Or a custom subdomain like `https://yourapp.railway.app`

### Step 5 — Update the App
Open the Flutter app on your phone:
- **Server URL** = `https://your-project.up.railway.app`
- **Username** = `admin`
- **Password** = `Admin1234`

### Step 6 — Share with All Users
Give everyone the same Railway URL. They all use the same server = shared data!

---

## Add PostgreSQL for Production (Recommended)

In Railway dashboard:
1. Click **"+ New"** → **"Database"** → **"PostgreSQL"**
2. Railway automatically sets `DATABASE_URL` in your service
3. Restart the service → data now stored in PostgreSQL (persistent!)

---

## Connect OneDrive (Optional)
After deploying:
1. Open app → OneDrive tab → Connect
2. Follow device-code auth
3. Copy the `ONEDRIVE_REFRESH_TOKEN` from Railway logs
4. Add it as an environment variable in Railway

---

## Free Tier Limits
- ✅ 500 hours/month (enough for 24/7 with 1 service)
- ✅ 1 GB RAM, 1 GB storage
- ✅ Custom domains supported
- ⚠️ SQLite data resets on redeploy → use PostgreSQL for persistence
