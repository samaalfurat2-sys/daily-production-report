from __future__ import annotations

import uuid
from datetime import date, datetime
from typing import Optional, List, Dict, Any

from pydantic import BaseModel, Field


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class UserInfo(BaseModel):
    id: uuid.UUID
    username: str
    full_name: Optional[str] = None
    preferred_locale: str = "ar"
    roles: List[str] = []
    unit_permissions: Dict[str, bool] = {}


class ShiftCreate(BaseModel):
    report_date: date
    shift_code: str = Field(min_length=1, max_length=10)


class ShiftBase(BaseModel):
    id: uuid.UUID
    report_date: date
    shift_code: str
    status: str
    notes: Optional[str] = None
    created_at: datetime


class BlowReportIn(BaseModel):
    preforms_per_carton: int = 1248
    prev_cartons: Optional[float] = None
    received_cartons: Optional[float] = None
    next_cartons: Optional[float] = None
    product_cartons: Optional[float] = None
    waste_preforms_pcs: Optional[int] = None
    waste_scrap_pcs: Optional[int] = None
    waste_bottles_pcs: Optional[int] = None
    counter_value: Optional[int] = None
    stock075_issued: Optional[float] = None
    stock075_received: Optional[float] = None
    stock15_issued: Optional[float] = None
    stock15_received: Optional[float] = None


class FillingReportIn(BaseModel):
    caps_per_carton: int = 5500
    prev_cartons: Optional[float] = None
    received_cartons: Optional[float] = None
    next_cartons: Optional[float] = None
    waste_caps_pcs: Optional[int] = None
    waste_scrap_pcs: Optional[int] = None
    waste_bottles_pcs: Optional[int] = None
    counter_value: Optional[int] = None
    stock_issued: Optional[float] = None
    stock_received: Optional[float] = None


class LabelReportIn(BaseModel):
    labels_per_roll: int = 23000
    prev_rolls: Optional[float] = None
    received_rolls: Optional[float] = None
    next_rolls: Optional[float] = None
    waste_grams: Optional[float] = None
    stock075_issued: Optional[float] = None
    stock075_received: Optional[float] = None
    stock15_issued: Optional[float] = None
    stock15_received: Optional[float] = None


class ShrinkReportIn(BaseModel):
    kg_per_roll: float = 25
    kg_per_carton: float = 0.055
    prev_rolls: Optional[float] = None
    received_rolls: Optional[float] = None
    next_rolls: Optional[float] = None
    waste_kg: Optional[float] = None
    screen_counter: Optional[int] = None
    stock075_issued: Optional[float] = None
    stock075_received: Optional[float] = None
    stock15_issued: Optional[float] = None
    stock15_received: Optional[float] = None


class DieselReportIn(BaseModel):
    generator1_total_reading: Optional[float] = None
    generator1_consumed: Optional[float] = None
    generator2_total_reading: Optional[float] = None
    generator2_consumed: Optional[float] = None
    main_tank_received: Optional[float] = None


class ShiftDetail(ShiftBase):
    blow: Optional[BlowReportIn] = None
    filling: Optional[FillingReportIn] = None
    label: Optional[LabelReportIn] = None
    shrink: Optional[ShrinkReportIn] = None
    diesel: Optional[DieselReportIn] = None
    computed: Dict[str, Any] = {}
    inventory_posted: bool = False


class WarehouseOut(BaseModel):
    id: uuid.UUID
    code: str
    type: str
    name_ar: str
    name_en: str
    is_active: bool


class InventoryItemOut(BaseModel):
    id: uuid.UUID
    code: str
    item_type: str
    name_ar: str
    name_en: str
    uom: str
    is_active: bool


class InventoryTxnCreate(BaseModel):
    warehouse_code: str
    item_code: str
    txn_type: str = Field(pattern="^(RECEIVE|ISSUE|ADJUST)$")
    qty: float
    txn_date: date
    note: Optional[str] = None


class InventoryTxnOut(BaseModel):
    id: uuid.UUID
    warehouse_code: str
    warehouse_name_ar: str
    warehouse_name_en: str
    item_code: str
    item_name_ar: str
    item_name_en: str
    txn_type: str
    qty: float
    txn_date: date
    reference_type: Optional[str] = None
    reference_id: Optional[str] = None
    note: Optional[str] = None
    created_at: datetime


class StockRow(BaseModel):
    warehouse_code: str
    warehouse_name_ar: str
    warehouse_name_en: str
    item_code: str
    item_name_ar: str
    item_name_en: str
    uom: str
    qty_on_hand: float
