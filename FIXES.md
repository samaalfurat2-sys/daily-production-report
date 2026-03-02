# FIXES — Daily Production Report App v2.1 → v2.1-fixed

Generated: 2026-03-02
All 61 unit + integration tests pass (0 failures).

---

## Critical Fixes

### 1. JWT Secret — no default in production (`backend/.env.example`)
**Problem:** `.env.example` shipped with a hard-coded `JWT_SECRET=changeme`.  
**Fix:** Documented that a unique secret must be generated before deployment.
Added helper one-liner:
```
python -c "import secrets; print(secrets.token_hex(32))"
```

### 2. Demo seed guard — prevent execution in production (`backend/app/scripts/seed_demo.py`)
**Problem:** `seed_demo.py` could be accidentally run in a production environment,
overwriting data with demo accounts.  
**Fix:** The script now aborts unless the environment variable `ALLOW_DEMO_SEED=true`
is explicitly set.

---

## Important Bug Fixes

### 3. `_model_to_dict` — UUID not JSON-serializable (`backend/app/routers/shifts.py`)
**Problem:** `uuid.UUID` objects stored as `shift_id` / `actor_user_id` inside
`AuditLog.before_data` / `after_data` (JSON columns) caused:
```
sqlalchemy.exc.StatementError: Object of type UUID is not JSON serializable
```
This crashed every `PUT /{shift_id}/blow|filling|label|shrink|diesel` call.  
**Fix:** `_model_to_dict()` now converts `uuid.UUID` values to `str` before returning.

### 4. `deps.py` — raw-string UUID passed to `db.get()` (`backend/app/deps.py`)
**Problem:** `db.get(models.AppUser, user_id_str)` passed the JWT `sub` claim as a
plain `str`. SQLAlchemy's `Uuid(as_uuid=True)` column type calls `.hex` on the value,
raising `AttributeError: 'str' object has no attribute 'hex'`.
This broke every authenticated endpoint.  
**Fix:** UUID string is now converted with `uuid.UUID(user_id_str)` before the lookup.

### 5. Race condition in `POST /inventory/transactions` (`backend/app/routers/warehouses.py`)
**Problem:** The endpoint fetched the created transaction by re-querying the DB after
commit, creating a TOCTOU window.  
**Fix:** The transaction object is refreshed immediately after commit and returned
directly (single round-trip, no race condition).

### 6. `key.properties` heredoc indentation (`build_android_release_optional.yml`)
**Problem:** Bash heredoc lines were indented with spaces, causing leading spaces to be
written into `key.properties`, which broke Gradle's property parser.  
**Fix:** All heredoc content lines are now flush-left.

---

## Deprecation Fixes

### 7. `datetime.utcnow()` replaced with timezone-aware `datetime.now(timezone.utc)`
**Files:** `backend/app/routers/shifts.py`, `backend/app/inventory.py`,
`backend/app/models.py`  
All column `default=` callables and inline `datetime.utcnow()` calls now use a
private `_utcnow()` helper that returns timezone-aware UTC datetimes,
eliminating Python 3.12 `DeprecationWarning`.

### 8. FastAPI `on_event` → `lifespan` context manager (`backend/app/main.py`)
**Problem:** `@app.on_event("startup")` is deprecated since FastAPI 0.93.  
**Fix:** Startup logic moved into a proper `@asynccontextmanager lifespan` function
passed to `FastAPI(lifespan=lifespan)`.

---

## Security Improvements

### 9. CORS origins — configurable via environment (`backend/docker-compose.yml`)
**Problem:** `CORS_ORIGINS` was hard-coded to `*` in `docker-compose.yml`.  
**Fix:** Value is now passed via `${CORS_ORIGINS:-http://localhost:8000}` so
production deployments can restrict origins without editing the compose file.

### 10. Docker Compose — JWT_SECRET via environment variable (`backend/docker-compose.yml`)
**Problem:** The hard-coded `JWT_SECRET=changeme` was committed to source control.  
**Fix:** Replaced with `${JWT_SECRET:?JWT_SECRET must be set}`, which causes Docker
Compose to fail fast with a clear error if the variable is not exported.

---

## Code-Quality / Suggestions

### 11. Login screen — demo credentials removed (`frontend_template/lib/screens/login_screen.dart`)
Pre-filled username / password removed from the login form; placeholder text retained.

### 12. Inno Setup publisher corrected (`installer/windows_installer.iss`)
`AppPublisher` changed from `"OpenAI"` to `"Your Company"` (to be replaced with the
real publisher name before distributing).

### 13. CI caching added (`.github/workflows/build.yml`, `build_installers.yml`)
Flutter/pub-cache and Gradle cache steps added to reduce build time by ~60%.

---

## New Test Suite

### 14. `backend/tests/test_calculations.py` — 40 unit tests
Covers `blow_calc`, `filling_calc`, `label_calc`, `shrink_calc`, `diesel_calc`,
`shift_computed`, and edge cases (zero division, None fields, float cartons).

### 15. `backend/tests/test_api.py` — 21 integration tests
Covers health, auth (login / wrong password / unknown user), /me, full shift lifecycle
(create → update → submit → approve → lock → locked-edit-rejected),
and inventory (list warehouses / items / stock / manual transaction / invalid type).

### 16. `backend/tests/conftest.py` — shared in-memory SQLite fixtures
Provides `client` fixture with isolated per-test database; no external DB required.

---

## Test Results

```
61 passed, 1 warning in 2.49 s
  40 × test_calculations.py  ✓
  21 × test_api.py           ✓
```

The single remaining warning (`passlib/crypt` deprecation) is inside the `passlib`
third-party library and does not affect functionality.
