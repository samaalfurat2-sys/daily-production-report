from app.database import SessionLocal, Base, engine
from app import models
from app.security import hash_password


def ensure_roles_and_units(db):
    role_names = ["admin", "supervisor", "operator", "viewer", "warehouse_clerk", "warehouse_supervisor"]
    for name in role_names:
        if not db.query(models.Role).filter(models.Role.name == name).first():
            db.add(models.Role(name=name))

    units = [
        ("blow", "النفخ", "Blow"),
        ("filling", "التعبئة", "Filling"),
        ("label", "ليبل", "Label"),
        ("shrink", "شرنك", "Shrink"),
        ("diesel", "سولار", "Diesel"),
    ]
    for code, ar, en in units:
        if not db.query(models.Unit).filter(models.Unit.code == code).first():
            db.add(models.Unit(code=code, name_ar=ar, name_en=en))
    db.commit()


def ensure_warehouses_and_items(db):
    warehouses = [
        ("RM", "RAW", "مخزن المواد الخام", "Raw Materials Warehouse"),
        ("FG", "FINISHED", "مخزن المنتج النهائي", "Finished Goods Warehouse"),
    ]
    for code, typ, ar, en in warehouses:
        if not db.query(models.Warehouse).filter(models.Warehouse.code == code).first():
            db.add(models.Warehouse(code=code, type=typ, name_ar=ar, name_en=en))

    items = [
        ("RM_PREFORM_CARTON", "RAW_MATERIAL", "بريفورم كرتون", "Preform Carton", "carton"),
        ("RM_CAPS_CARTON", "RAW_MATERIAL", "أغطية كرتون", "Caps Carton", "carton"),
        ("RM_LABEL_ROLL", "RAW_MATERIAL", "ليبل روله", "Label Roll", "roll"),
        ("RM_SHRINK_ROLL", "RAW_MATERIAL", "شرنك روله", "Shrink Roll", "roll"),
        ("RM_DIESEL_LITER", "RAW_MATERIAL", "سولار", "Diesel", "liter"),
        ("FG_TOTAL_CARTON", "FINISHED_GOOD", "منتج نهائي كرتون", "Finished Goods Carton", "carton"),
    ]
    for code, typ, ar, en, uom in items:
        if not db.query(models.InventoryItem).filter(models.InventoryItem.code == code).first():
            db.add(models.InventoryItem(code=code, item_type=typ, name_ar=ar, name_en=en, uom=uom))
    db.commit()


def main(username="admin", password="Admin1234", full_name="System Admin"):
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    ensure_roles_and_units(db)
    ensure_warehouses_and_items(db)

    user = db.query(models.AppUser).filter(models.AppUser.username == username).first()
    admin_role = db.query(models.Role).filter(models.Role.name == "admin").first()
    if user:
        print(f"User '{username}' already exists.")
        return

    user = models.AppUser(
        username=username,
        full_name=full_name,
        preferred_locale="ar",
        password_hash=hash_password(password),
        is_active=True,
    )
    db.add(user)
    db.flush()
    user.roles.append(admin_role)
    db.commit()
    print(f"Created admin user: {username}")


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--username", default="admin")
    parser.add_argument("--password", default="Admin1234")
    parser.add_argument("--full-name", default="System Admin")
    args = parser.parse_args()

    main(username=args.username, password=args.password, full_name=args.full_name)
