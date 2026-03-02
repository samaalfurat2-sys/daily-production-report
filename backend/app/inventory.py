from __future__ import annotations

from datetime import datetime, timezone


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)
from typing import Optional

from sqlalchemy.orm import Session

from app import models
from app.calculations import shift_computed


RAW_WAREHOUSE_CODE = "RM"
FINISHED_WAREHOUSE_CODE = "FG"

RAW_ITEM_CODES = {
    "blow": "RM_PREFORM_CARTON",
    "filling": "RM_CAPS_CARTON",
    "label": "RM_LABEL_ROLL",
    "shrink": "RM_SHRINK_ROLL",
    "diesel": "RM_DIESEL_LITER",
}

FG_ITEM_CODE = "FG_TOTAL_CARTON"


def get_warehouse_by_code(db: Session, code: str) -> models.Warehouse:
    wh = db.query(models.Warehouse).filter(models.Warehouse.code == code).first()
    if not wh:
        raise ValueError(f"Warehouse not found: {code}")
    return wh


def get_item_by_code(db: Session, code: str) -> models.InventoryItem:
    item = db.query(models.InventoryItem).filter(models.InventoryItem.code == code).first()
    if not item:
        raise ValueError(f"Item not found: {code}")
    return item


def create_inventory_txn(
    db: Session,
    *,
    warehouse: models.Warehouse,
    item: models.InventoryItem,
    txn_type: str,
    qty: float,
    txn_date,
    created_by,
    reference_type: Optional[str] = None,
    reference_id: Optional[str] = None,
    note: Optional[str] = None,
):
    if qty == 0:
        return None
    db.add(
        models.InventoryTransaction(
            warehouse_id=warehouse.id,
            item_id=item.id,
            txn_type=txn_type,
            qty=qty,
            txn_date=txn_date,
            created_by=created_by,
            reference_type=reference_type,
            reference_id=reference_id,
            note=note,
            created_at=_utcnow(),
        )
    )
    return True


def post_shift_inventory(db: Session, shift: models.ShiftRecord, user_id) -> None:
    existing = db.query(models.InventoryPosting).filter(models.InventoryPosting.shift_id == shift.id).first()
    if existing and existing.status == "POSTED":
        return

    computed = shift_computed(shift)
    rm = get_warehouse_by_code(db, RAW_WAREHOUSE_CODE)
    fg = get_warehouse_by_code(db, FINISHED_WAREHOUSE_CODE)

    # Raw material issues
    raw_qty_map = {
        "blow": float(computed["blow"].get("consumed_cartons") or 0),
        "filling": float(computed["filling"].get("consumed_cartons") or 0),
        "label": float(computed["label"].get("consumed_rolls") or 0),
        "shrink": float(computed["shrink"].get("consumed_rolls") or 0),
        "diesel": float(computed["diesel"].get("total_usage") or 0),
    }

    for unit_code, qty in raw_qty_map.items():
        if qty <= 0:
            continue
        item = get_item_by_code(db, RAW_ITEM_CODES[unit_code])
        create_inventory_txn(
            db,
            warehouse=rm,
            item=item,
            txn_type="ISSUE",
            qty=qty,
            txn_date=shift.report_date,
            created_by=user_id,
            reference_type="SHIFT_REPORT",
            reference_id=str(shift.id),
            note=f"Auto-posted from shift {shift.shift_code}",
        )

    # Finished goods receive
    finished_qty = float(computed["summary"].get("finished_cartons_total") or 0)
    if finished_qty > 0:
        item = get_item_by_code(db, FG_ITEM_CODE)
        create_inventory_txn(
            db,
            warehouse=fg,
            item=item,
            txn_type="RECEIVE",
            qty=finished_qty,
            txn_date=shift.report_date,
            created_by=user_id,
            reference_type="SHIFT_REPORT",
            reference_id=str(shift.id),
            note=f"Auto-posted from shift {shift.shift_code}",
        )

    if not existing:
        db.add(models.InventoryPosting(shift_id=shift.id, status="POSTED", posted_by=user_id, posted_at=_utcnow()))
    else:
        existing.status = "POSTED"
        existing.posted_by = user_id
        existing.posted_at = _utcnow()
