from __future__ import annotations

from datetime import date, datetime, timezone


def _utcnow() -> datetime:
    """Timezone-aware UTC now (replaces deprecated datetime.utcnow())."""
    return datetime.now(timezone.utc)
from typing import List, Optional
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app import models
from app.deps import get_db, get_current_user, require_roles, require_unit_edit, user_roles
from app.schemas import ShiftCreate, ShiftDetail, BlowReportIn, FillingReportIn, LabelReportIn, ShrinkReportIn, DieselReportIn, ShiftBase
from app.config import settings
from app.calculations import shift_computed
from app.inventory import post_shift_inventory

router = APIRouter(prefix="/shifts", tags=["shifts"])


def _shift_index(code: str) -> int:
    order = settings.shift_order_list()
    if code in order:
        return order.index(code)
    try:
        return int(code)
    except Exception:
        return 999


def find_previous_shift(db: Session, report_date: date, shift_code: str) -> Optional[models.ShiftRecord]:
    order = settings.shift_order_list()
    idx = _shift_index(shift_code)

    if shift_code in order and idx > 0:
        earlier = order[:idx]
        candidates = db.query(models.ShiftRecord).filter(
            models.ShiftRecord.report_date == report_date,
            models.ShiftRecord.shift_code.in_(earlier),
        ).all()
        if candidates:
            candidates.sort(key=lambda s: (_shift_index(s.shift_code), s.created_at))
            return candidates[-1]

    last = db.query(models.ShiftRecord).filter(models.ShiftRecord.report_date < report_date).order_by(
        models.ShiftRecord.report_date.desc(), models.ShiftRecord.created_at.desc()
    ).first()
    if not last:
        return None

    same_day = db.query(models.ShiftRecord).filter(models.ShiftRecord.report_date == last.report_date).all()
    if same_day:
        same_day.sort(key=lambda s: (_shift_index(s.shift_code), s.created_at))
        return same_day[-1]
    return last


def _audit(db: Session, shift_id, entity: str, action: str, actor_id, before: dict | None, after: dict | None):
    db.add(models.AuditLog(
        shift_id=shift_id,
        entity=entity,
        action=action,
        actor_user_id=actor_id,
        before_data=before,
        after_data=after,
        event_time=_utcnow(),
    ))


def _model_to_dict(obj) -> dict:
    """Serialize a SQLAlchemy model row to a plain dict.

    Converts types that are not natively JSON-serializable:
    - datetime / date  → ISO-8601 string
    - uuid.UUID        → str  (fixes 'Object of type UUID is not JSON serializable'
                               when the dict is stored in a JSON column such as
                               AuditLog.before_data / after_data)
    """
    if obj is None:
        return {}
    data = {}
    for col in obj.__table__.columns:
        val = getattr(obj, col.name)
        if isinstance(val, (datetime, date)):
            data[col.name] = val.isoformat()
        elif isinstance(val, uuid.UUID):
            data[col.name] = str(val)
        else:
            data[col.name] = val
    return data


def _detail(shift: models.ShiftRecord) -> ShiftDetail:
    computed = shift_computed(shift)
    posted = any(p.status == "POSTED" for p in (shift.postings or []))
    return ShiftDetail(
        id=shift.id,
        report_date=shift.report_date,
        shift_code=shift.shift_code,
        status=shift.status,
        notes=shift.notes,
        created_at=shift.created_at,
        blow=BlowReportIn(**_model_to_dict(shift.blow)) if shift.blow else None,
        filling=FillingReportIn(**_model_to_dict(shift.filling)) if shift.filling else None,
        label=LabelReportIn(**_model_to_dict(shift.label)) if shift.label else None,
        shrink=ShrinkReportIn(**_model_to_dict(shift.shrink)) if shift.shrink else None,
        diesel=DieselReportIn(**_model_to_dict(shift.diesel)) if shift.diesel else None,
        computed=computed,
        inventory_posted=posted,
    )


@router.get("", response_model=List[ShiftBase])
def list_shifts(
    db: Session = Depends(get_db),
    user: models.AppUser = Depends(get_current_user),
    date_from: Optional[date] = Query(default=None),
    date_to: Optional[date] = Query(default=None),
    status: Optional[str] = Query(default=None),
    limit: int = Query(default=100, ge=1, le=500),
):
    q = db.query(models.ShiftRecord)
    if date_from:
        q = q.filter(models.ShiftRecord.report_date >= date_from)
    if date_to:
        q = q.filter(models.ShiftRecord.report_date <= date_to)
    if status:
        q = q.filter(models.ShiftRecord.status == status)
    shifts = q.order_by(models.ShiftRecord.report_date.desc(), models.ShiftRecord.created_at.desc()).limit(limit).all()
    return [ShiftBase(id=s.id, report_date=s.report_date, shift_code=s.shift_code, status=s.status, notes=s.notes, created_at=s.created_at) for s in shifts]


@router.post("", response_model=ShiftDetail)
def create_shift(payload: ShiftCreate, db: Session = Depends(get_db), user: models.AppUser = Depends(get_current_user)):
    existing = db.query(models.ShiftRecord).filter(
        models.ShiftRecord.report_date == payload.report_date,
        models.ShiftRecord.shift_code == payload.shift_code,
    ).first()
    if existing:
        return _detail(existing)

    prev = find_previous_shift(db, payload.report_date, payload.shift_code)
    shift = models.ShiftRecord(
        report_date=payload.report_date,
        shift_code=payload.shift_code,
        status="Draft",
        created_by=user.id,
        created_at=_utcnow(),
    )
    db.add(shift)
    db.flush()

    db.add(models.BlowReport(shift_id=shift.id, prev_cartons=(prev.blow.next_cartons if prev and prev.blow else None), preforms_per_carton=(prev.blow.preforms_per_carton if prev and prev.blow else 1248)))
    db.add(models.FillingReport(shift_id=shift.id, prev_cartons=(prev.filling.next_cartons if prev and prev.filling else None), caps_per_carton=(prev.filling.caps_per_carton if prev and prev.filling else 5500)))
    db.add(models.LabelReport(shift_id=shift.id, prev_rolls=(prev.label.next_rolls if prev and prev.label else None), labels_per_roll=(prev.label.labels_per_roll if prev and prev.label else 23000)))
    db.add(models.ShrinkReport(shift_id=shift.id, prev_rolls=(prev.shrink.next_rolls if prev and prev.shrink else None), kg_per_roll=(prev.shrink.kg_per_roll if prev and prev.shrink else 25), kg_per_carton=(prev.shrink.kg_per_carton if prev and prev.shrink else 0.055)))
    db.add(models.DieselReport(shift_id=shift.id))

    _audit(db, shift.id, "shift_record", "CREATE", user.id, None, {"report_date": str(payload.report_date), "shift_code": payload.shift_code})
    db.commit()
    db.refresh(shift)
    return _detail(shift)


@router.get("/{shift_id}", response_model=ShiftDetail)
def get_shift(shift_id: uuid.UUID, db: Session = Depends(get_db), user: models.AppUser = Depends(get_current_user)):
    shift = db.query(models.ShiftRecord).filter(models.ShiftRecord.id == shift_id).first()
    if not shift:
        raise HTTPException(status_code=404, detail="Shift not found")
    return _detail(shift)


def _check_edit_allowed(shift: models.ShiftRecord, user: models.AppUser):
    roles = user_roles(user)
    if shift.status == "Locked":
        raise HTTPException(status_code=409, detail="Shift is locked")
    if shift.status in ("Submitted", "Approved") and "admin" not in roles and "supervisor" not in roles:
        raise HTTPException(status_code=403, detail="Only supervisor/admin can edit a submitted/approved shift")


def _update_unit(shift_id, payload, db: Session, user: models.AppUser, unit_attr: str, entity_name: str):
    shift = db.query(models.ShiftRecord).filter(models.ShiftRecord.id == shift_id).first()
    unit = getattr(shift, unit_attr, None) if shift else None
    if not shift or not unit:
        raise HTTPException(status_code=404, detail=f"{entity_name} not found")
    _check_edit_allowed(shift, user)
    before = _model_to_dict(unit)
    for k, v in payload.model_dump().items():
        setattr(unit, k, v)
    unit.updated_at = _utcnow()
    _audit(db, shift.id, entity_name, "UPDATE", user.id, before, _model_to_dict(unit))
    db.commit()
    db.refresh(shift)
    return _detail(shift)


@router.put("/{shift_id}/blow", response_model=ShiftDetail)
def update_blow(shift_id: uuid.UUID, payload: BlowReportIn, db: Session = Depends(get_db), user: models.AppUser = Depends(require_unit_edit("blow"))):
    return _update_unit(shift_id, payload, db, user, "blow", "blow_report")


@router.put("/{shift_id}/filling", response_model=ShiftDetail)
def update_filling(shift_id: uuid.UUID, payload: FillingReportIn, db: Session = Depends(get_db), user: models.AppUser = Depends(require_unit_edit("filling"))):
    return _update_unit(shift_id, payload, db, user, "filling", "filling_report")


@router.put("/{shift_id}/label", response_model=ShiftDetail)
def update_label(shift_id: uuid.UUID, payload: LabelReportIn, db: Session = Depends(get_db), user: models.AppUser = Depends(require_unit_edit("label"))):
    return _update_unit(shift_id, payload, db, user, "label", "label_report")


@router.put("/{shift_id}/shrink", response_model=ShiftDetail)
def update_shrink(shift_id: uuid.UUID, payload: ShrinkReportIn, db: Session = Depends(get_db), user: models.AppUser = Depends(require_unit_edit("shrink"))):
    return _update_unit(shift_id, payload, db, user, "shrink", "shrink_report")


@router.put("/{shift_id}/diesel", response_model=ShiftDetail)
def update_diesel(shift_id: uuid.UUID, payload: DieselReportIn, db: Session = Depends(get_db), user: models.AppUser = Depends(require_unit_edit("diesel"))):
    return _update_unit(shift_id, payload, db, user, "diesel", "diesel_report")


@router.post("/{shift_id}/submit", response_model=ShiftDetail)
def submit_shift(shift_id: uuid.UUID, db: Session = Depends(get_db), user: models.AppUser = Depends(get_current_user)):
    shift = db.query(models.ShiftRecord).filter(models.ShiftRecord.id == shift_id).first()
    if not shift:
        raise HTTPException(status_code=404, detail="Shift not found")
    if shift.status == "Locked":
        raise HTTPException(status_code=409, detail="Locked shift cannot be submitted")
    shift.status = "Submitted"
    shift.submitted_by = user.id
    shift.submitted_at = _utcnow()
    _audit(db, shift.id, "shift_record", "SUBMIT", user.id, None, {"status": shift.status})
    db.commit()
    db.refresh(shift)
    return _detail(shift)


@router.post("/{shift_id}/approve", response_model=ShiftDetail)
def approve_shift(shift_id: uuid.UUID, db: Session = Depends(get_db), user: models.AppUser = Depends(require_roles("supervisor", "warehouse_supervisor"))):
    shift = db.query(models.ShiftRecord).filter(models.ShiftRecord.id == shift_id).first()
    if not shift:
        raise HTTPException(status_code=404, detail="Shift not found")
    if shift.status == "Locked":
        raise HTTPException(status_code=409, detail="Locked shift cannot be approved")
    shift.status = "Approved"
    shift.approved_by = user.id
    shift.approved_at = _utcnow()
    post_shift_inventory(db, shift, user.id)
    _audit(db, shift.id, "shift_record", "APPROVE", user.id, None, {"status": shift.status, "inventory_posted": True})
    db.commit()
    db.refresh(shift)
    return _detail(shift)


@router.post("/{shift_id}/lock", response_model=ShiftDetail)
def lock_shift(shift_id: uuid.UUID, db: Session = Depends(get_db), user: models.AppUser = Depends(require_roles("supervisor", "warehouse_supervisor"))):
    shift = db.query(models.ShiftRecord).filter(models.ShiftRecord.id == shift_id).first()
    if not shift:
        raise HTTPException(status_code=404, detail="Shift not found")
    shift.status = "Locked"
    shift.locked_at = _utcnow()
    _audit(db, shift.id, "shift_record", "LOCK", user.id, None, {"status": shift.status})
    db.commit()
    db.refresh(shift)
    return _detail(shift)
