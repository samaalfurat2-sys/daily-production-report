"""
Integration tests for core API endpoints using FastAPI TestClient + SQLite temp file.

Run with:
    cd backend
    pip install pytest httpx "bcrypt==4.0.1"
    pytest tests/ -v

Note on bcrypt compatibility:
    passlib 1.7.x has a known issue with bcrypt>=4.1 (no __about__ attribute).
    Pin bcrypt==4.0.1 for tests, or upgrade to passlib 2.x when released.
"""
import pytest

# conftest.py sets DATABASE_URL, JWT_SECRET, ALLOW_DEMO_SEED before this runs.
from fastapi.testclient import TestClient
from app.main import app          # triggers startup (creates tables, seeds roles)
from app.database import SessionLocal


# ── Seed admin user once ──────────────────────────────────────────────────────

def _seed_admin():
    from app import models
    from app.security import hash_password
    db = SessionLocal()
    try:
        if db.query(models.AppUser).filter(models.AppUser.username == "testadmin").first():
            return
        admin_role = db.query(models.Role).filter(models.Role.name == "admin").first()
        if not admin_role:
            return  # roles not yet seeded — startup not fired; skip
        user = models.AppUser(
            username="testadmin",
            password_hash=hash_password("TestPass1"),
            full_name="Test Admin",
            preferred_locale="en",
            is_active=True,
        )
        db.add(user)
        db.flush()
        user.roles.append(admin_role)
        db.commit()
    finally:
        db.close()


# ── Fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture(scope="session")
def client():
    with TestClient(app) as c:
        # Startup event fires here → tables created, roles + warehouses seeded
        _seed_admin()
        yield c


@pytest.fixture(scope="session")
def admin_token(client):
    r = client.post("/auth/login", data={"username": "testadmin", "password": "TestPass1"})
    assert r.status_code == 200, r.text
    return r.json()["access_token"]


@pytest.fixture(scope="session")
def auth_headers(admin_token):
    return {"Authorization": f"Bearer {admin_token}"}


# ═══════════════════════════════════════════════════════════════════════════════
# Health
# ═══════════════════════════════════════════════════════════════════════════════

class TestHealth:
    def test_health_returns_ok(self, client):
        r = client.get("/health")
        assert r.status_code == 200
        assert r.json()["ok"] is True


# ═══════════════════════════════════════════════════════════════════════════════
# Auth
# ═══════════════════════════════════════════════════════════════════════════════

class TestAuth:
    def test_login_success(self, admin_token):
        assert isinstance(admin_token, str) and len(admin_token) > 10

    def test_login_wrong_password(self, client):
        r = client.post("/auth/login", data={"username": "testadmin", "password": "wrong"})
        assert r.status_code == 401

    def test_login_unknown_user(self, client):
        r = client.post("/auth/login", data={"username": "nobody", "password": "x"})
        assert r.status_code == 401


# ═══════════════════════════════════════════════════════════════════════════════
# /me
# ═══════════════════════════════════════════════════════════════════════════════

class TestMe:
    def test_me_returns_user_info(self, client, auth_headers):
        r = client.get("/me", headers=auth_headers)
        assert r.status_code == 200
        data = r.json()
        assert data["username"] == "testadmin"
        assert "admin" in data["roles"]

    def test_me_requires_auth(self, client):
        r = client.get("/me")
        assert r.status_code == 401


# ═══════════════════════════════════════════════════════════════════════════════
# Shifts
# ═══════════════════════════════════════════════════════════════════════════════

class TestShifts:
    def test_create_shift(self, client, auth_headers):
        r = client.post("/shifts", json={"report_date": "2025-01-15", "shift_code": "A"}, headers=auth_headers)
        assert r.status_code == 200
        data = r.json()
        assert data["status"] == "Draft"
        assert data["shift_code"] == "A"

    def test_create_shift_idempotent(self, client, auth_headers):
        payload = {"report_date": "2025-01-20", "shift_code": "B"}
        r1 = client.post("/shifts", json=payload, headers=auth_headers)
        r2 = client.post("/shifts", json=payload, headers=auth_headers)
        assert r1.status_code == r2.status_code == 200
        assert r1.json()["id"] == r2.json()["id"]

    def test_get_shift(self, client, auth_headers):
        r = client.post("/shifts", json={"report_date": "2025-02-01", "shift_code": "C"}, headers=auth_headers)
        shift_id = r.json()["id"]
        r2 = client.get(f"/shifts/{shift_id}", headers=auth_headers)
        assert r2.status_code == 200
        assert r2.json()["id"] == shift_id

    def test_get_shift_not_found(self, client, auth_headers):
        r = client.get("/shifts/00000000-0000-0000-0000-000000000000", headers=auth_headers)
        assert r.status_code == 404

    def test_list_shifts(self, client, auth_headers):
        r = client.get("/shifts", headers=auth_headers)
        assert r.status_code == 200
        assert isinstance(r.json(), list)

    def test_update_blow_unit(self, client, auth_headers):
        r = client.post("/shifts", json={"report_date": "2025-03-01", "shift_code": "A"}, headers=auth_headers)
        shift_id = r.json()["id"]
        r2 = client.put(
            f"/shifts/{shift_id}/blow",
            json={"preforms_per_carton": 1248, "prev_cartons": 10, "received_cartons": 5, "next_cartons": 2, "product_cartons": 13},
            headers=auth_headers,
        )
        assert r2.status_code == 200
        data = r2.json()
        assert data["blow"]["product_cartons"] == 13
        assert data["computed"]["blow"]["consumed_cartons"] == pytest.approx(13.0)

    def test_submit_shift(self, client, auth_headers):
        r = client.post("/shifts", json={"report_date": "2025-04-01", "shift_code": "A"}, headers=auth_headers)
        shift_id = r.json()["id"]
        r2 = client.post(f"/shifts/{shift_id}/submit", headers=auth_headers)
        assert r2.status_code == 200
        assert r2.json()["status"] == "Submitted"

    def test_approve_shift_posts_inventory(self, client, auth_headers):
        r = client.post("/shifts", json={"report_date": "2025-05-01", "shift_code": "A"}, headers=auth_headers)
        shift_id = r.json()["id"]
        client.post(f"/shifts/{shift_id}/submit", headers=auth_headers)
        r2 = client.post(f"/shifts/{shift_id}/approve", headers=auth_headers)
        assert r2.status_code == 200
        assert r2.json()["status"] == "Approved"
        assert r2.json()["inventory_posted"] is True

    def test_lock_shift(self, client, auth_headers):
        r = client.post("/shifts", json={"report_date": "2025-06-01", "shift_code": "A"}, headers=auth_headers)
        shift_id = r.json()["id"]
        r2 = client.post(f"/shifts/{shift_id}/lock", headers=auth_headers)
        assert r2.status_code == 200
        assert r2.json()["status"] == "Locked"

    def test_cannot_edit_locked_shift(self, client, auth_headers):
        r = client.post("/shifts", json={"report_date": "2025-07-01", "shift_code": "A"}, headers=auth_headers)
        shift_id = r.json()["id"]
        client.post(f"/shifts/{shift_id}/lock", headers=auth_headers)
        r2 = client.put(f"/shifts/{shift_id}/blow", json={"preforms_per_carton": 1248}, headers=auth_headers)
        assert r2.status_code == 409


# ═══════════════════════════════════════════════════════════════════════════════
# Inventory / Warehouses
# ═══════════════════════════════════════════════════════════════════════════════

class TestInventory:
    def test_list_warehouses(self, client, auth_headers):
        r = client.get("/warehouses", headers=auth_headers)
        assert r.status_code == 200
        codes = [w["code"] for w in r.json()]
        assert "RM" in codes and "FG" in codes

    def test_list_items(self, client, auth_headers):
        r = client.get("/inventory/items", headers=auth_headers)
        assert r.status_code == 200
        codes = [i["code"] for i in r.json()]
        assert "RM_PREFORM_CARTON" in codes and "FG_TOTAL_CARTON" in codes

    def test_stock_on_hand(self, client, auth_headers):
        r = client.get("/inventory/stock", headers=auth_headers)
        assert r.status_code == 200
        assert isinstance(r.json(), list)

    def test_create_manual_transaction(self, client, auth_headers):
        payload = {"warehouse_code": "RM", "item_code": "RM_PREFORM_CARTON",
                   "txn_type": "RECEIVE", "qty": 100.0, "txn_date": "2025-01-01", "note": "Test receive"}
        r = client.post("/inventory/transactions", json=payload, headers=auth_headers)
        assert r.status_code == 200
        data = r.json()
        assert data["txn_type"] == "RECEIVE"
        assert data["qty"] == pytest.approx(100.0)
        assert data["warehouse_code"] == "RM"

    def test_transaction_invalid_type(self, client, auth_headers):
        payload = {"warehouse_code": "RM", "item_code": "RM_PREFORM_CARTON",
                   "txn_type": "INVALID", "qty": 10.0, "txn_date": "2025-01-01"}
        r = client.post("/inventory/transactions", json=payload, headers=auth_headers)
        assert r.status_code == 422
