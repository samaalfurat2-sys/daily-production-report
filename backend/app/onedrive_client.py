"""
Microsoft Graph / OneDrive integration client.

Authentication flow
-------------------
1. First-time setup:
   - Call `get_device_code()` → user visits the URL and enters the code
   - Call `exchange_device_code(device_code)` → returns access + refresh tokens
   - Save ONEDRIVE_REFRESH_TOKEN to .env / Railway env vars

2. Runtime (every request):
   - `get_access_token()` uses the stored refresh token to get a short-lived
     access token automatically.

Required environment variables
-------------------------------
ONEDRIVE_CLIENT_ID      – Azure App Registration client ID
ONEDRIVE_REFRESH_TOKEN  – long-lived token (set once after first-time setup)
ONEDRIVE_FOLDER         – OneDrive folder path, e.g. "ProductionReports"
"""

import os
import time
import logging
from typing import Optional, Dict, Any

import httpx

logger = logging.getLogger(__name__)

# ── Constants ──────────────────────────────────────────────────────────────────
# Using the public "Microsoft Office" client ID that supports device-code flow
# without needing a secret (PKCE / public client).
_DEFAULT_CLIENT_ID = os.environ.get(
    "ONEDRIVE_CLIENT_ID", "d3590ed6-52b3-4102-aeff-aad2292ab01c"
)
_TENANT = "consumers"   # personal Microsoft accounts
_SCOPES = "Files.ReadWrite offline_access"
_TOKEN_URL = f"https://login.microsoftonline.com/{_TENANT}/oauth2/v2.0/token"
_GRAPH_BASE = "https://graph.microsoft.com/v1.0"

# ── In-memory token cache ──────────────────────────────────────────────────────
_token_cache: Dict[str, Any] = {"access_token": None, "expires_at": 0}


# ── Public helpers ─────────────────────────────────────────────────────────────

def is_configured() -> bool:
    """Return True if OneDrive credentials are present in environment."""
    return bool(
        os.environ.get("ONEDRIVE_CLIENT_ID")
        and os.environ.get("ONEDRIVE_REFRESH_TOKEN")
    )


def get_device_code() -> Dict[str, str]:
    """
    Start device-code flow.  Returns dict with:
        user_code       – user types this at https://microsoft.com/devicelogin
        device_code     – pass to exchange_device_code()
        verification_uri
        expires_in
        message         – human-readable instruction
    """
    client_id = _DEFAULT_CLIENT_ID
    url = f"https://login.microsoftonline.com/{_TENANT}/oauth2/v2.0/devicecode"
    resp = httpx.post(url, data={
        "client_id": client_id,
        "scope": _SCOPES,
    }, timeout=15)
    resp.raise_for_status()
    data = resp.json()
    return {
        "user_code": data["user_code"],
        "device_code": data["device_code"],
        "verification_uri": data["verification_uri"],
        "expires_in": data["expires_in"],
        "message": data.get("message", ""),
    }


def exchange_device_code(device_code: str, poll_interval: int = 5,
                          max_wait: int = 300) -> Dict[str, str]:
    """
    Poll until the user completes authentication.
    Returns {"access_token": ..., "refresh_token": ...}.
    Raises RuntimeError on timeout or error.
    """
    client_id = _DEFAULT_CLIENT_ID
    deadline = time.time() + max_wait
    while time.time() < deadline:
        time.sleep(poll_interval)
        resp = httpx.post(_TOKEN_URL, data={
            "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
            "client_id": client_id,
            "device_code": device_code,
        }, timeout=15)
        data = resp.json()
        if "access_token" in data:
            return {
                "access_token": data["access_token"],
                "refresh_token": data.get("refresh_token", ""),
            }
        err = data.get("error", "")
        if err == "authorization_pending":
            continue
        raise RuntimeError(f"Device code exchange failed: {err} – {data.get('error_description','')}")
    raise RuntimeError("Device code flow timed out – user did not complete authentication.")


def get_access_token() -> str:
    """Return a valid access token, refreshing if necessary."""
    global _token_cache
    if _token_cache["access_token"] and time.time() < _token_cache["expires_at"] - 60:
        return _token_cache["access_token"]

    refresh_token = os.environ.get("ONEDRIVE_REFRESH_TOKEN", "")
    client_id = _DEFAULT_CLIENT_ID
    if not refresh_token:
        raise RuntimeError(
            "ONEDRIVE_REFRESH_TOKEN is not set. "
            "Run the /onedrive/setup endpoint first to authenticate."
        )

    resp = httpx.post(_TOKEN_URL, data={
        "grant_type": "refresh_token",
        "client_id": client_id,
        "refresh_token": refresh_token,
        "scope": _SCOPES,
    }, timeout=15)
    resp.raise_for_status()
    data = resp.json()
    _token_cache = {
        "access_token": data["access_token"],
        "expires_at": time.time() + data.get("expires_in", 3600),
    }
    # Update refresh token if a new one was returned
    new_refresh = data.get("refresh_token")
    if new_refresh:
        os.environ["ONEDRIVE_REFRESH_TOKEN"] = new_refresh
    return _token_cache["access_token"]


def _headers() -> Dict[str, str]:
    return {"Authorization": f"Bearer {get_access_token()}",
            "Content-Type": "application/json"}


def ensure_folder(folder_name: str) -> str:
    """Create folder in OneDrive root if it doesn't exist. Returns item ID."""
    # Try to get existing folder
    resp = httpx.get(
        f"{_GRAPH_BASE}/me/drive/root:/{folder_name}",
        headers=_headers(), timeout=15,
    )
    if resp.status_code == 200:
        return resp.json()["id"]

    # Create folder
    resp = httpx.post(
        f"{_GRAPH_BASE}/me/drive/root/children",
        headers=_headers(),
        json={"name": folder_name, "folder": {}, "@microsoft.graph.conflictBehavior": "replace"},
        timeout=15,
    )
    resp.raise_for_status()
    return resp.json()["id"]


def upload_file(folder_name: str, filename: str, content: bytes,
                content_type: str = "application/octet-stream") -> str:
    """
    Upload a file to OneDrive/<folder_name>/<filename>.
    Returns the webUrl of the uploaded file.
    Uses simple upload (≤4 MB) or upload session (>4 MB).
    """
    path = f"{folder_name}/{filename}"
    if len(content) <= 4 * 1024 * 1024:
        # Simple upload
        headers = {
            "Authorization": f"Bearer {get_access_token()}",
            "Content-Type": content_type,
        }
        resp = httpx.put(
            f"{_GRAPH_BASE}/me/drive/root:/{path}:/content",
            headers=headers,
            content=content,
            timeout=60,
        )
        resp.raise_for_status()
        return resp.json().get("webUrl", "")
    else:
        # Upload session for large files
        headers = _headers()
        sess_resp = httpx.post(
            f"{_GRAPH_BASE}/me/drive/root:/{path}:/createUploadSession",
            headers=headers,
            json={"item": {"@microsoft.graph.conflictBehavior": "replace"}},
            timeout=15,
        )
        sess_resp.raise_for_status()
        upload_url = sess_resp.json()["uploadUrl"]
        chunk_size = 3 * 1024 * 1024  # 3 MB
        total = len(content)
        web_url = ""
        for start in range(0, total, chunk_size):
            chunk = content[start: start + chunk_size]
            end = start + len(chunk) - 1
            chunk_headers = {
                "Content-Range": f"bytes {start}-{end}/{total}",
                "Content-Type": content_type,
            }
            r = httpx.put(upload_url, headers=chunk_headers, content=chunk, timeout=60)
            if r.status_code in (200, 201):
                web_url = r.json().get("webUrl", "")
        return web_url


def list_files(folder_name: str):
    """List files in OneDrive/<folder_name>. Returns list of dicts."""
    resp = httpx.get(
        f"{_GRAPH_BASE}/me/drive/root:/{folder_name}:/children",
        headers=_headers(),
        params={"$select": "name,size,lastModifiedDateTime,webUrl"},
        timeout=15,
    )
    if resp.status_code == 404:
        return []
    resp.raise_for_status()
    return resp.json().get("value", [])


def download_file(folder_name: str, filename: str) -> bytes:
    """Download a file from OneDrive/<folder_name>/<filename>."""
    path = f"{folder_name}/{filename}"
    resp = httpx.get(
        f"{_GRAPH_BASE}/me/drive/root:/{path}:/content",
        headers=_headers(),
        follow_redirects=True,
        timeout=60,
    )
    resp.raise_for_status()
    return resp.content
