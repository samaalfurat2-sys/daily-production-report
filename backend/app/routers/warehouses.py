from __future__ import annotations

from typing import List, Optional
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import func, case

from app import models
from app.deps import get_db, get_current_user, require_roles
from app.schemas import WarehouseOut, InventoryItemOut, InventoryTxnCreate, InventoryTxnOut, StockRow
from app.inventory import get_warehouse_by_code, get_item_by_code, create_inventory_txn

router = APIRouter(tags=["inventory"])


def _txn_to_out(row: models.InventoryTransaction) -> InventoryTxnOut:
    """Convert an ORM InventoryTransaction to the output schema."""
    return InventoryTxnOut(
        id=row.id,
        warehouse_code=row.warehouse.code,
        warehouse_name_ar=row.warehouse.name_ar,
        warehouse_name_en=row.warehouse.name_en,
        item_code=row.item.code,
        item_name_ar=row.item.name_ar,
        item_name_en=row.item.name_en,
        txn_type=row.txn_type,
        qty=float(row.qty),
        txn_date=row.txn_date,
        reference_type=row.reference_type,
        reference_id=row.reference_id,
        note=row.note,
        created_at=row.created_at,
    )


@router.get("/warehouses", response_model=List[WarehouseOut])
def list_warehouses(db: Session = Depends(get_db), _: models.AppUser = Depends(get_current_user)):
    rows = db.query(models.Warehouse).order_by(models.Warehouse.type, models.Warehouse.code).all()
    return [
        WarehouseOut(id=r.id, code=r.code, type=r.type, name_ar=r.name_ar, name_en=r.name_en, is_active=r.is_active)
        for r in rows
    ]


@router.get("/inventory/items", response_model=List[InventoryItemOut])
def list_items(db: Session = Depends(get_db), _: models.AppUser = Depends(get_current_user)):
    rows = db.query(models.InventoryItem).order_by(models.InventoryItem.item_type, models.InventoryItem.code).all()
    return [
        InventoryItemOut(id=r.id, code=r.code, item_type=r.item_type, name_ar=r.name_ar, name_en=r.name_en, uom=r.uom, is_active=r.is_active)
        for r in rows
    ]


@router.get("/inventory/transactions", response_model=List[InventoryTxnOut])
def list_transactions(
    db: Session = Depends(get_db),
    _: models.AppUser = Depends(get_current_user),
    warehouse_code: Optional[str] = Query(default=None),
    item_code: Optional[str] = Query(default=None),
    limit: int = Query(default=200, ge=1, le=1000),
):
    q = db.query(models.InventoryTransaction).join(models.Warehouse).join(models.InventoryItem)
    if warehouse_code:
        q = q.filter(models.Warehouse.code == warehouse_code)
    if item_code:
        q = q.filter(models.InventoryItem.code == item_code)
    rows = q.order_by(
        models.InventoryTransaction.txn_date.desc(),
        models.InventoryTransaction.created_at.desc(),
    ).limit(limit).all()
    return [_txn_to_out(r) for r in rows]


@router.get("/inventory/stock", response_model=List[StockRow])
def stock_on_hand(db: Session = Depends(get_db), _: models.AppUser = Depends(get_current_user)):
    rows = (
        db.query(
            models.Warehouse.code,
            models.Warehouse.name_ar,
            models.Warehouse.name_en,
            models.InventoryItem.code,
            models.InventoryItem.name_ar,
            models.InventoryItem.name_en,
            models.InventoryItem.uom,
            func.sum(
                case(
                    (models.InventoryTransaction.txn_type.in_(["RECEIVE", "ADJUST"]), models.InventoryTransaction.qty),
                    else_=-models.InventoryTransaction.qty,
                )
            ).label("qty_on_hand"),
        )
        .join(models.InventoryTransaction, models.InventoryTransaction.warehouse_id == models.Warehouse.id)
        .join(models.InventoryItem, models.InventoryItem.id == models.InventoryTransaction.item_id)
        .group_by(
            models.Warehouse.code, models.Warehouse.name_ar, models.Warehouse.name_en,
            models.InventoryItem.code, models.InventoryItem.name_ar, models.InventoryItem.name_en,
            models.InventoryItem.uom,
        )
        .order_by(models.Warehouse.code, models.InventoryItem.code)
        .all()
    )
    return [
        StockRow(
            warehouse_code=r[0],
            warehouse_name_ar=r[1],
            warehouse_name_en=r[2],
            item_code=r[3],
            item_name_ar=r[4],
            item_name_en=r[5],
            uom=r[6],
            qty_on_hand=float(r[7] or 0),
        )
        for r in rows
    ]


@router.post("/inventory/transactions", response_model=InventoryTxnOut)
def create_transaction(
    payload: InventoryTxnCreate,
    db: Session = Depends(get_db),
    user: models.AppUser = Depends(require_roles("admin", "warehouse_clerk", "warehouse_supervisor")),
):
    warehouse = get_warehouse_by_code(db, payload.warehouse_code)
    item = get_item_by_code(db, payload.item_code)

    # FIX: Capture the new ORM object directly instead of re-querying by
    # created_at (which is a race condition in a multi-user environment).
    txn = models.InventoryTransaction(
        warehouse_id=warehouse.id,
        item_id=item.id,
        txn_type=payload.txn_type,
        qty=payload.qty,
        txn_date=payload.txn_date,
        created_by=user.id,
        reference_type="MANUAL",
        note=payload.note,
    )
    db.add(txn)
    db.commit()
    db.refresh(txn)

    return _txn_to_out(txn)
