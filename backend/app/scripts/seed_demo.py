"""
Seed demo users for development/testing ONLY.

⚠️  PRODUCTION SAFETY GUARD:
    This script will refuse to run if the environment variable
    ALLOW_DEMO_SEED is not explicitly set to "yes".
    In production, create users via the API or create_admin.py instead.
"""
import os
import sys

from app.database import SessionLocal, Base, engine
from app import models
from app.security import hash_password
from app.scripts.create_admin import ensure_roles_and_units, ensure_warehouses_and_items

# ── Production Safety Guard ────────────────────────────────────────────────────
_ALLOW = os.environ.get("ALLOW_DEMO_SEED", "").strip().lower()
_DATABASE_URL = os.environ.get("DATABASE_URL", "sqlite")

if "postgresql" in _DATABASE_URL and _ALLOW != "yes":
    print(
        "\n[seed_demo] ❌  REFUSED: DATABASE_URL points to PostgreSQL.\n"
        "   This script seeds insecure demo credentials and must NOT run in production.\n"
        "   If you really intend this (e.g. staging), set:  ALLOW_DEMO_SEED=yes\n",
        file=sys.stderr,
    )
    sys.exit(1)


def main():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    ensure_roles_and_units(db)
    ensure_warehouses_and_items(db)

    def ensure_user(username, password, full_name, roles, perms=None):
        user = db.query(models.AppUser).filter(models.AppUser.username == username).first()
        if user:
            return user
        user = models.AppUser(
            username=username,
            password_hash=hash_password(password),
            full_name=full_name,
            preferred_locale="ar",
        )
        db.add(user)
        db.flush()
        for role_name in roles:
            role = db.query(models.Role).filter(models.Role.name == role_name).first()
            if role:
                user.roles.append(role)
        for unit_code, can_edit in (perms or {}).items():
            db.add(models.UserUnitPermission(user_id=user.id, unit_code=unit_code, can_edit=can_edit))
        return user

    ensure_user("admin",      "Admin1234",      "System Admin",    ["admin"])
    ensure_user("supervisor", "Supervisor123",  "Shift Supervisor",["supervisor", "warehouse_supervisor"])
    ensure_user(
        "operator", "Operator123", "Blow Operator", ["operator"],
        {"blow": True, "filling": True, "label": True, "shrink": True, "diesel": True},
    )
    ensure_user("viewer", "Viewer123", "Read Only", ["viewer"])

    db.commit()
    print("✅  Demo users seeded.")
    print("⚠️  These accounts use WEAK passwords — do NOT expose this backend publicly.")


if __name__ == "__main__":
    main()
