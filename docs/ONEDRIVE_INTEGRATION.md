# OneDrive Integration Guide

## Overview

The app integrates with **Microsoft OneDrive** via the Microsoft Graph API to:

1. **Auto-backup the SQLite database** to OneDrive
2. **Export shift reports** as Excel (`.xlsx`) files
3. **Export inventory/stock data** as Excel files
4. **List files** stored in your OneDrive folder from inside the app

---

## Architecture

```
Flutter App  ──POST /onedrive/sync/all──▶  FastAPI Backend  ──Graph API──▶  OneDrive
                                                │
                                         onedrive_client.py
                                         (device-code auth + token refresh)
```

---

## First-Time Setup

### Step 1 – Register Azure App (one-time)

1. Go to [Azure Portal → App Registrations](https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade)
2. Click **New registration** → give it a name (e.g. `ProductionReportApp`)
3. Select **"Personal Microsoft accounts only"** (for personal OneDrive)  
   Or **"Work/school accounts"** for OneDrive for Business
4. Under **Authentication**, add platform **"Mobile and desktop applications"**  
   and enable the `https://login.microsoftonline.com/common/oauth2/nativeclient` redirect
5. Under **API Permissions**, add:
   - `Files.ReadWrite.AppFolder` *(for App Folder only)*  
   - OR `Files.ReadWrite` *(for full OneDrive)*
6. Copy the **Application (client) ID** → set as `ONEDRIVE_CLIENT_ID` in `.env`

> **Shortcut:** The default client ID (`d3590ed6-52b3-4102-aeff-aad2292ab01c`) is Microsoft's 
> own Office app ID and works for personal OneDrive accounts. For organizational accounts, 
> register your own app.

---

### Step 2 – Authenticate (device-code flow)

Open the app → go to the **OneDrive** tab (bottom nav) → tap **"Connect OneDrive Account"**

The app will:
1. Request a device code from the backend
2. Show you a URL (`https://microsoft.com/devicelogin`) and a short code
3. Open the URL in a browser, sign in with your Microsoft account, enter the code
4. Tap **"✅ I completed sign-in"** in the app

The backend exchanges the code for tokens and saves the `refresh_token`.

> **For production deployment:** After completing auth, copy the `ONEDRIVE_REFRESH_TOKEN` 
> value from the server logs and save it as an environment variable in Railway/Render 
> so it persists across restarts.

---

### Step 3 – Set Environment Variable

Add to your `.env` (or Railway dashboard):

```env
ONEDRIVE_CLIENT_ID=d3590ed6-52b3-4102-aeff-aad2292ab01c
ONEDRIVE_REFRESH_TOKEN=<token from step 2>
ONEDRIVE_FOLDER=ProductionReports
```

---

## Using the OneDrive Screen

| Button | Action |
|--------|--------|
| 🔄 Sync Everything | Runs all exports + DB backup at once |
| 📊 Export Shifts | Creates `shifts_YYYY-MM-DD.xlsx` in OneDrive |
| 📦 Export Inventory | Creates `inventory_YYYY-MM-DD.xlsx` in OneDrive |
| 💾 Backup Database | Uploads `backup_YYYY-MM-DD.db` to OneDrive |
| Refresh (top-right) | Re-checks connection status and file list |

---

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/onedrive/status` | Check if configured |
| GET | `/onedrive/setup` | Start device-code auth |
| POST | `/onedrive/setup/complete` | Exchange device code for tokens |
| POST | `/onedrive/export/shifts` | Export shifts → Excel |
| POST | `/onedrive/export/inventory` | Export inventory → Excel |
| POST | `/onedrive/backup/db` | Backup DB file |
| GET | `/onedrive/files` | List files in OneDrive folder |
| POST | `/onedrive/sync/all` | Run all in one call |

---

## Troubleshooting

| Error | Solution |
|-------|----------|
| `ONEDRIVE_REFRESH_TOKEN not set` | Complete the device-code auth flow first |
| `invalid_grant` | Token expired — re-authenticate via the app |
| `Files not appearing` | Check `ONEDRIVE_FOLDER` matches the folder name |
| `403 Forbidden` | App needs `Files.ReadWrite` permission in Azure |

---

## Android Sign-In Troubleshooting

### Why the OAuth redirect fails on Android

When using the browser-redirect (PKCE) flow rather than the device-code flow,
Android must route the `msauth://` redirect back to the app via an
**intent-filter**.  If the intent-filter is missing or the redirect URI is not
registered in Azure, the browser cannot return to the app and sign-in stalls.

The **device-code flow** (default) is NOT affected by this — it works on all
platforms without any redirect URI configuration.

### Setup checklist

- [ ] `INTERNET` permission in `AndroidManifest.xml` *(already set)*.
- [ ] `android:launchMode="singleTask"` on `MainActivity` *(already set)*.
- [ ] `msauth://` intent-filter present in `AndroidManifest.xml` with the
      correct `android:host` matching your `applicationId` *(already set for
      the default package name `com.example.production_report_app`)*.
- [ ] Azure redirect URI registered for your package name **and** SHA-1
      signing fingerprint (see README.md → Step 3).
- [ ] `_sha1Placeholder` in `lib/auth/onedrive_auth.dart` replaced with the
      base64-encoded SHA-1 from your Azure App Registration (see README.md →
      Step 4).

### Quick diagnostic commands

```bash
# Verify the intent-filter is installed on-device
adb shell dumpsys package com.example.production_report_app | grep -A5 "msauth"

# Stream auth-related log output while reproducing the issue
adb logcat | grep -iE "msal|oauth|OneDriveAuth|flutter"

# Save a log snapshot for analysis
adb logcat -d > /tmp/logcat_$(date +%Y%m%d_%H%M%S).txt
```

See **README.md → "Android OneDrive Sign-In Setup"** for the full step-by-step
guide including SHA-1 fingerprint retrieval and Azure registration.
See **`commands.txt`** at the repo root for the complete keytool / adb reference.
