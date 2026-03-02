from __future__ import annotations

import uuid
from datetime import datetime, date, timezone
from typing import Optional, List


def _utcnow() -> datetime:
    """Timezone-aware UTC timestamp for SQLAlchemy column defaults."""
    return datetime.now(timezone.utc)

from sqlalchemy import (
    String,
    Boolean,
    DateTime,
    Date,
    ForeignKey,
    Integer,
    Numeric,
    Text,
    CheckConstraint,
    UniqueConstraint,
    JSON,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class AppUser(Base):
    __tablename__ = "app_user"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    username: Mapped[str] = mapped_column(String, unique=True, index=True)
    full_name: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    preferred_locale: Mapped[str] = mapped_column(String, default="ar")
    password_hash: Mapped[str] = mapped_column(String)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    roles: Mapped[List["Role"]] = relationship("Role", secondary="user_role", back_populates="users")
    unit_permissions: Mapped[List["UserUnitPermission"]] = relationship("UserUnitPermission", back_populates="user")


class Role(Base):
    __tablename__ = "role"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String, unique=True)

    users: Mapped[List["AppUser"]] = relationship("AppUser", secondary="user_role", back_populates="roles")


class UserRole(Base):
    __tablename__ = "user_role"

    user_id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("app_user.id", ondelete="CASCADE"), primary_key=True)
    role_id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("role.id", ondelete="CASCADE"), primary_key=True)


class Unit(Base):
    __tablename__ = "unit"

    code: Mapped[str] = mapped_column(String, primary_key=True)
    name_ar: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    name_en: Mapped[Optional[str]] = mapped_column(String, nullable=True)


class UserUnitPermission(Base):
    __tablename__ = "user_unit_permission"

    user_id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("app_user.id", ondelete="CASCADE"), primary_key=True)
    unit_code: Mapped[str] = mapped_column(String, ForeignKey("unit.code", ondelete="CASCADE"), primary_key=True)
    can_edit: Mapped[bool] = mapped_column(Boolean, default=False)

    user: Mapped[AppUser] = relationship("AppUser", back_populates="unit_permissions")
    unit: Mapped[Unit] = relationship("Unit")


class ShiftRecord(Base):
    __tablename__ = "shift_record"
    __table_args__ = (
        UniqueConstraint("report_date", "shift_code", name="uq_shift"),
        CheckConstraint("status IN ('Draft','Submitted','Approved','Locked')", name="chk_status"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    report_date: Mapped[date] = mapped_column(Date, index=True)
    shift_code: Mapped[str] = mapped_column(String)
    status: Mapped[str] = mapped_column(String, default="Draft", index=True)

    created_by: Mapped[Optional[uuid.UUID]] = mapped_column(Uuid(as_uuid=True), ForeignKey("app_user.id"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    submitted_by: Mapped[Optional[uuid.UUID]] = mapped_column(Uuid(as_uuid=True), ForeignKey("app_user.id"), nullable=True)
    submitted_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    approved_by: Mapped[Optional[uuid.UUID]] = mapped_column(Uuid(as_uuid=True), ForeignKey("app_user.id"), nullable=True)
    approved_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    locked_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    blow: Mapped[Optional["BlowReport"]] = relationship("BlowReport", back_populates="shift", uselist=False, cascade="all, delete-orphan")
    filling: Mapped[Optional["FillingReport"]] = relationship("FillingReport", back_populates="shift", uselist=False, cascade="all, delete-orphan")
    label: Mapped[Optional["LabelReport"]] = relationship("LabelReport", back_populates="shift", uselist=False, cascade="all, delete-orphan")
    shrink: Mapped[Optional["ShrinkReport"]] = relationship("ShrinkReport", back_populates="shift", uselist=False, cascade="all, delete-orphan")
    diesel: Mapped[Optional["DieselReport"]] = relationship("DieselReport", back_populates="shift", uselist=False, cascade="all, delete-orphan")
    postings: Mapped[List["InventoryPosting"]] = relationship("InventoryPosting", back_populates="shift", cascade="all, delete-orphan")


class BlowReport(Base):
    __tablename__ = "blow_report"

    shift_id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("shift_record.id", ondelete="CASCADE"), primary_key=True)
    preforms_per_carton: Mapped[int] = mapped_column(Integer, default=1248)
    prev_cartons: Mapped[Optional[float]] = mapped_column(Numeric(12, 3), nullable=True)
    received_cartons: Mapped[Optional[float]] = mapped_column(Numeric(12, 3), nullable=True)
    next_cartons: Mapped[Optional[float]] = mapped_column(Numeric(12, 3), nullable=True)
    product_cartons: Mapped[Optional[float]] = mapped_column(Numeric(12, 3), nullable=True)
    waste_preforms_pcs: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    waste_scrap_pcs: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    waste_bottles_pcs: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    counter_value: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    stock075_issued: Mapped[Optional[float]] = mapped_column(Numeric(12, 3), nullable=True)
    stock075_received: Mapped[Optional[float]] = mapped_column(Numeric(12, 3), nullable=True)
    stock15_issued: Mapped[Optional[float]] = mapped_column(Numeric(12, 3), nullable=True)
    stock15_received: Mapped[Optional[float]] = mapped_column(Numeric(12, 3), nullable=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    shift: Mapped[ShiftRecord] = relationship("ShiftRecord", back_populates="blow")


class FillingReport(Base):
    __tablename__ = "filling_report"

    shift_id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("shift_record.id", ondelete="CASCADE"), primary_key=True)
    caps_per_carton: Mapped[int] = mapped_column(Integer, default=5500)
    prev_cartons: Mapped[Optional[float]] = mapped_column(Numeric(12, 3), nullable=True)
    received_cartons: Mapped[Optional[float]] = mapped_column(Numeric(12, 3), nullable=True)
    next_cartons: Mapped[Optional[float]] = mapped_column(Numeric(12, 3), nullable=True)
    waste_caps_pcs: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    waste_scrap_pcs: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    waste_bottles_pcs: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    counter_value: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    stock_issued: Mapped[Optional[float]] = mapped_column(Numeric(12, 3), nullable=True)
    stock_received: Mapped[Optional[float]] = mapped_column(Numeric(12, 3), nullable=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    shift: Mapped[ShiftRecord] = relationship("ShiftRecord", back_populates="filling")


class LabelReport(Base):
    __tablename__ = "label_report"

    shift_id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("shift_record.id", ondelete="CASCADE"), primary_key=True)
    labels_per_roll: Mapped[int] = mapped_column(Integer, default=23000)
    prev_rolls: Mapped[Optional[float]] = mapped_column(Numeric(12, 3), nullable=True)
    received_rolls: Mapped[Optional[float]] = mapped_column(Numeric(12, 3), nullable=True)
    next_rolls: Mapped[Optional[float]] = mapped_column(Numeric(12, 3), nullable=True)
    waste_grams: Mapped[Optional[float]] = mapped_column(Numeric(12, 3), nullable=True)
    stock075_issued: Mapped[Optional[float]] = mapped_column(Numeric(12, 3), nullable=True)
    stock075_received: Mapped[Optional[float]] = mapped_column(Numeric(12, 3), nullable=True)
    stock15_issued: Mapped[Optional[float]] = mapped_column(Numeric(12, 3), nullable=True)
    stock15_received: Mapped[Optional[float]] = mapped_column(Numeric(12, 3), nullable=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    shift: Mapped[ShiftRecord] = relationship("ShiftRecord", back_populates="label")


class ShrinkReport(Base):
    __tablename__ = "shrink_report"

    shift_id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("shift_record.id", ondelete="CASCADE"), primary_key=True)
    kg_per_roll: Mapped[float] = mapped_column(Numeric(12, 3), default=25)
    kg_per_carton: Mapped[float] = mapped_column(Numeric(12, 6), default=0.055)
    prev_rolls: Mapped[Optional[float]] = mapped_column(Numeric(12, 3), nullable=True)
    received_rolls: Mapped[Optional[float]] = mapped_column(Numeric(12, 3), nullable=True)
    next_rolls: Mapped[Optional[float]] = mapped_column(Numeric(12, 3), nullable=True)
    waste_kg: Mapped[Optional[float]] = mapped_column(Numeric(12, 3), nullable=True)
    screen_counter: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    stock075_issued: Mapped[Optional[float]] = mapped_column(Numeric(12, 3), nullable=True)
    stock075_received: Mapped[Optional[float]] = mapped_column(Numeric(12, 3), nullable=True)
    stock15_issued: Mapped[Optional[float]] = mapped_column(Numeric(12, 3), nullable=True)
    stock15_received: Mapped[Optional[float]] = mapped_column(Numeric(12, 3), nullable=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    shift: Mapped[ShiftRecord] = relationship("ShiftRecord", back_populates="shrink")


class DieselReport(Base):
    __tablename__ = "diesel_report"

    shift_id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("shift_record.id", ondelete="CASCADE"), primary_key=True)
    generator1_total_reading: Mapped[Optional[float]] = mapped_column(Numeric(12, 3), nullable=True)
    generator1_consumed: Mapped[Optional[float]] = mapped_column(Numeric(12, 3), nullable=True)
    generator2_total_reading: Mapped[Optional[float]] = mapped_column(Numeric(12, 3), nullable=True)
    generator2_consumed: Mapped[Optional[float]] = mapped_column(Numeric(12, 3), nullable=True)
    main_tank_received: Mapped[Optional[float]] = mapped_column(Numeric(12, 3), nullable=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    shift: Mapped[ShiftRecord] = relationship("ShiftRecord", back_populates="diesel")


class Warehouse(Base):
    __tablename__ = "warehouse"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    code: Mapped[str] = mapped_column(String, unique=True, index=True)
    type: Mapped[str] = mapped_column(String)  # RAW / FINISHED
    name_ar: Mapped[str] = mapped_column(String)
    name_en: Mapped[str] = mapped_column(String)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    transactions: Mapped[List["InventoryTransaction"]] = relationship("InventoryTransaction", back_populates="warehouse")


class InventoryItem(Base):
    __tablename__ = "inventory_item"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    code: Mapped[str] = mapped_column(String, unique=True, index=True)
    item_type: Mapped[str] = mapped_column(String)  # RAW_MATERIAL / FINISHED_GOOD
    name_ar: Mapped[str] = mapped_column(String)
    name_en: Mapped[str] = mapped_column(String)
    uom: Mapped[str] = mapped_column(String)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    transactions: Mapped[List["InventoryTransaction"]] = relationship("InventoryTransaction", back_populates="item")


class InventoryTransaction(Base):
    __tablename__ = "inventory_transaction"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    warehouse_id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("warehouse.id", ondelete="CASCADE"))
    item_id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("inventory_item.id", ondelete="CASCADE"))
    txn_type: Mapped[str] = mapped_column(String)  # RECEIVE / ISSUE / ADJUST
    qty: Mapped[float] = mapped_column(Numeric(14, 3))
    txn_date: Mapped[date] = mapped_column(Date, index=True)
    reference_type: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    reference_id: Mapped[Optional[str]] = mapped_column(String, nullable=True, index=True)
    note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_by: Mapped[Optional[uuid.UUID]] = mapped_column(Uuid(as_uuid=True), ForeignKey("app_user.id"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    warehouse: Mapped[Warehouse] = relationship("Warehouse", back_populates="transactions")
    item: Mapped[InventoryItem] = relationship("InventoryItem", back_populates="transactions")


class InventoryPosting(Base):
    __tablename__ = "inventory_posting"
    __table_args__ = (UniqueConstraint("shift_id", name="uq_inventory_posting_shift"),)

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    shift_id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("shift_record.id", ondelete="CASCADE"))
    status: Mapped[str] = mapped_column(String, default="POSTED")
    posted_by: Mapped[Optional[uuid.UUID]] = mapped_column(Uuid(as_uuid=True), ForeignKey("app_user.id"), nullable=True)
    posted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    shift: Mapped[ShiftRecord] = relationship("ShiftRecord", back_populates="postings")


class AuditLog(Base):
    __tablename__ = "audit_log"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    shift_id: Mapped[Optional[uuid.UUID]] = mapped_column(Uuid(as_uuid=True), ForeignKey("shift_record.id", ondelete="CASCADE"), nullable=True)
    entity: Mapped[str] = mapped_column(String)
    action: Mapped[str] = mapped_column(String)
    actor_user_id: Mapped[Optional[uuid.UUID]] = mapped_column(Uuid(as_uuid=True), ForeignKey("app_user.id"), nullable=True)
    before_data: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    after_data: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    event_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
