"""
OneDrive sync router.

Endpoints
---------
GET  /onedrive/status          – check if OneDrive is configured
GET  /onedrive/setup           – start device-code auth flow
POST /onedrive/setup/complete  – complete auth and save refresh token
POST /onedrive/backup/db       – upload SQLite DB file to OneDrive
POST /onedrive/export/shifts   – export shift reports as Excel to OneDrive
POST /onedrive/export/inventory – export inventory/stock as Excel to OneDrive
GET  /onedrive/files           – list files in OneDrive folder
POST /onedrive/sync/all        – run all exports + DB backup in one call
"""

import io
import os
import logging
from datetime import date, datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app import models
from app.deps import get_db, require_roles
from app import onedrive_client as od

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/onedrive", tags=["OneDrive"])

_FOLDER = os.environ.get("ONEDRIVE_FOLDER", "ProductionReports")

# ── device-code state (in-memory, single-instance) ────────────────────────────
_pending_device_code: dict = {}


# ── Schemas ───────────────────────────────────────────────────────────────────

class SetupStartResponse(BaseModel):
    user_code: str
    verification_uri: str
    message: str
    device_code: str
    expires_in: int


class SetupCompleteRequest(BaseModel):
    device_code: str


class SetupCompleteResponse(BaseModel):
    ok: bool
    message: str
    refresh_token_preview: str   # first 8 chars only, for confirmation


class StatusResponse(BaseModel):
    configured: bool
    folder: str
    message: str


class SyncResult(BaseModel):
    ok: bool
    db_backup: Optional[str] = None
    shifts_excel: Optional[str] = None
    inventory_excel: Optional[str] = None
    errors: List[str] = []


# ── Helpers ───────────────────────────────────────────────────────────────────

def _require_onedrive():
    if not od.is_configured():
        raise HTTPException(
            status_code=503,
            detail="OneDrive is not configured. Call GET /onedrive/setup first.",
        )


def _build_shifts_excel(db: Session) -> bytes:
    """Export all approved/locked shifts with sub-reports to Excel bytes."""
    try:
        import openpyxl
        from openpyxl.styles import Font, PatternFill, Alignment
    except ImportError:
        raise HTTPException(
            status_code=500,
            detail="openpyxl is not installed. Add it to requirements.txt.",
        )

    wb = openpyxl.Workbook()

    # ── Sheet 1: Shift Summary ────────────────────────────────────────────────
    ws = wb.active
    ws.title = "Shifts"
    header = ["ID", "Date", "Shift", "Unit", "Status", "Operator", "Supervisor",
              "Created", "Approved"]
    _excel_header_row(ws, header)
    shifts = db.query(models.ShiftRecord).order_by(models.ShiftRecord.shift_date.desc()).all()
    for s in shifts:
        ws.append([
            str(s.id),
            str(s.shift_date),
            s.shift_code,
            s.unit_code,
            s.status,
            s.operator.full_name if s.operator else "",
            s.supervisor.full_name if s.supervisor else "",
            str(s.created_at)[:19] if s.created_at else "",
            str(s.approved_at)[:19] if s.approved_at else "",
        ])
    _autofit(ws)

    # ── Sheet 2: Blow Reports ─────────────────────────────────────────────────
    ws2 = wb.create_sheet("Blow")
    blow_header = ["Shift ID", "Date", "Shift", "raw_input", "good_output",
                   "waste", "waste_pct", "notes"]
    _excel_header_row(ws2, blow_header)
    for s in shifts:
        if s.blow:
            b = s.blow
            ws2.append([str(s.id), str(s.shift_date), s.shift_code,
                        b.raw_input, b.good_output, b.waste,
                        round(b.waste_pct or 0, 2), b.notes or ""])
    _autofit(ws2)

    # ── Sheet 3: Filling Reports ──────────────────────────────────────────────
    ws3 = wb.create_sheet("Filling")
    fill_header = ["Shift ID", "Date", "Shift", "preforms_used", "bottles_good",
                   "bottles_waste", "waste_pct", "notes"]
    _excel_header_row(ws3, fill_header)
    for s in shifts:
        if s.filling:
            f = s.filling
            ws3.append([str(s.id), str(s.shift_date), s.shift_code,
                        f.preforms_used, f.bottles_good, f.bottles_waste,
                        round(f.waste_pct or 0, 2), f.notes or ""])
    _autofit(ws3)

    # ── Sheet 4: Label Reports ────────────────────────────────────────────────
    ws4 = wb.create_sheet("Label")
    lbl_header = ["Shift ID", "Date", "Shift", "bottles_in", "labelled_good",
                  "label_waste", "waste_pct", "notes"]
    _excel_header_row(ws4, lbl_header)
    for s in shifts:
        if s.label:
            l = s.label
            ws4.append([str(s.id), str(s.shift_date), s.shift_code,
                        l.bottles_in, l.labelled_good, l.label_waste,
                        round(l.waste_pct or 0, 2), l.notes or ""])
    _autofit(ws4)

    # ── Sheet 5: Diesel Reports ───────────────────────────────────────────────
    ws5 = wb.create_sheet("Diesel")
    die_header = ["Shift ID", "Date", "Shift", "opening_meter", "closing_meter",
                  "consumption_litres", "notes"]
    _excel_header_row(ws5, die_header)
    for s in shifts:
        if s.diesel:
            d = s.diesel
            ws5.append([str(s.id), str(s.shift_date), s.shift_code,
                        d.opening_meter, d.closing_meter,
                        d.consumption_litres, d.notes or ""])
    _autofit(ws5)

    buf = io.BytesIO()
    wb.save(buf)
    return buf.getvalue()


def _build_inventory_excel(db: Session) -> bytes:
    """Export warehouses, items and recent transactions to Excel bytes."""
    try:
        import openpyxl
    except ImportError:
        raise HTTPException(
            status_code=500,
            detail="openpyxl is not installed. Add it to requirements.txt.",
        )

    wb = openpyxl.Workbook()

    # ── Stock on hand ─────────────────────────────────────────────────────────
    ws = wb.active
    ws.title = "Stock"
    _excel_header_row(ws, ["Warehouse", "Item Code", "Item Name", "Unit",
                            "Balance Qty", "Last Updated"])
    warehouses = db.query(models.Warehouse).all()
    for wh in warehouses:
        for item in wh.items:
            balance = sum(
                (t.qty if t.direction == "in" else -t.qty)
                for t in item.transactions
            )
            last_tx = max(
                (t.created_at for t in item.transactions if t.created_at),
                default=None,
            )
            ws.append([wh.name, item.code, item.name, item.unit,
                       round(balance, 3),
                       str(last_tx)[:19] if last_tx else ""])
    _autofit(ws)

    # ── Transactions ──────────────────────────────────────────────────────────
    ws2 = wb.create_sheet("Transactions")
    _excel_header_row(ws2, ["Date", "Warehouse", "Item", "Direction",
                             "Qty", "Reference", "Notes", "Clerk"])
    txns = (db.query(models.InventoryTransaction)
            .order_by(models.InventoryTransaction.created_at.desc())
            .limit(2000)
            .all())
    for t in txns:
        ws2.append([
            str(t.created_at)[:19] if t.created_at else "",
            t.item.warehouse.name if t.item and t.item.warehouse else "",
            t.item.name if t.item else "",
            t.direction,
            t.qty,
            t.reference or "",
            t.notes or "",
            t.clerk.full_name if t.clerk else "",
        ])
    _autofit(ws2)

    buf = io.BytesIO()
    wb.save(buf)
    return buf.getvalue()


def _excel_header_row(ws, headers: list):
    from openpyxl.styles import Font, PatternFill, Alignment
    ws.append(headers)
    for cell in ws[1]:
        cell.font = Font(bold=True, color="FFFFFF")
        cell.fill = PatternFill("solid", fgColor="1F4E79")
        cell.alignment = Alignment(horizontal="center")


def _autofit(ws):
    for col in ws.columns:
        max_len = max((len(str(c.value or "")) for c in col), default=10)
        ws.column_dimensions[col[0].column_letter].width = min(max_len + 4, 50)


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.get("/status", response_model=StatusResponse)
def onedrive_status():
    """Check whether OneDrive is configured and ready."""
    configured = od.is_configured()
    return StatusResponse(
        configured=configured,
        folder=_FOLDER,
        message="Ready — OneDrive sync is active." if configured
                else "Not configured. Visit GET /onedrive/setup to authenticate.",
    )


@router.get("/setup", response_model=SetupStartResponse)
def onedrive_setup_start():
    """
    Start Microsoft device-code authentication.
    Returns a user_code the user must enter at https://microsoft.com/devicelogin.
    Then call POST /onedrive/setup/complete with the device_code.
    """
    global _pending_device_code
    data = od.get_device_code()
    _pending_device_code = data
    return SetupStartResponse(**data)


@router.post("/setup/complete", response_model=SetupCompleteResponse)
def onedrive_setup_complete(body: SetupCompleteRequest):
    """
    Poll Microsoft until the user completes sign-in, then save the refresh token.
    Set the returned refresh_token as ONEDRIVE_REFRESH_TOKEN environment variable.
    """
    try:
        tokens = od.exchange_device_code(body.device_code)
        refresh = tokens["refresh_token"]
        os.environ["ONEDRIVE_REFRESH_TOKEN"] = refresh
        preview = refresh[:8] + "..." if len(refresh) > 8 else refresh
        return SetupCompleteResponse(
            ok=True,
            message=(
                "✅ OneDrive authenticated successfully!\n"
                f"Save this refresh token as ONEDRIVE_REFRESH_TOKEN env var:\n{refresh}"
            ),
            refresh_token_preview=preview,
        )
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/backup/db")
def backup_database(_: None = Depends(require_roles("admin"))):
    """
    Upload the SQLite database file to OneDrive/<ONEDRIVE_FOLDER>/backups/.
    Only works when DATABASE_URL points to a local SQLite file.
    """
    _require_onedrive()
    db_url = os.environ.get("DATABASE_URL", "sqlite:///./production_app.db")
    if "sqlite" not in db_url:
        raise HTTPException(
            status_code=400,
            detail="DB backup to OneDrive only supported for SQLite databases.",
        )
    # Extract file path from URL  sqlite:///./production_app.db
    db_path = db_url.replace("sqlite:///", "").replace("sqlite://", "")
    if not os.path.exists(db_path):
        # Try common locations
        for candidate in ["./production_app.db", "production_app.db", "/app/production_app.db"]:
            if os.path.exists(candidate):
                db_path = candidate
                break
        else:
            raise HTTPException(status_code=404,
                                detail=f"SQLite file not found at {db_path}")

    with open(db_path, "rb") as f:
        content = f.read()

    ts = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    filename = f"production_app_{ts}.db"
    folder = f"{_FOLDER}/backups"
    web_url = od.upload_file(folder, filename, content, "application/octet-stream")
    return {"ok": True, "filename": filename, "web_url": web_url,
            "size_kb": round(len(content) / 1024, 1)}


@router.post("/export/shifts")
def export_shifts_excel(
    db: Session = Depends(get_db),
    _: None = Depends(require_roles("supervisor")),
):
    """Export all shift reports to an Excel file in OneDrive."""
    _require_onedrive()
    content = _build_shifts_excel(db)
    ts = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    filename = f"shifts_{ts}.xlsx"
    folder = f"{_FOLDER}/exports"
    web_url = od.upload_file(
        folder, filename, content,
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    )
    return {"ok": True, "filename": filename, "web_url": web_url,
            "size_kb": round(len(content) / 1024, 1)}


@router.post("/export/inventory")
def export_inventory_excel(
    db: Session = Depends(get_db),
    _: None = Depends(require_roles("warehouse_supervisor")),
):
    """Export stock on hand + transactions to an Excel file in OneDrive."""
    _require_onedrive()
    content = _build_inventory_excel(db)
    ts = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    filename = f"inventory_{ts}.xlsx"
    folder = f"{_FOLDER}/exports"
    web_url = od.upload_file(
        folder, filename, content,
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    )
    return {"ok": True, "filename": filename, "web_url": web_url,
            "size_kb": round(len(content) / 1024, 1)}


@router.get("/files")
def list_onedrive_files(_: None = Depends(require_roles("supervisor"))):
    """List files in the OneDrive production reports folder."""
    _require_onedrive()
    files = od.list_files(_FOLDER)
    return {"folder": _FOLDER, "files": files}


@router.post("/sync/all", response_model=SyncResult)
def sync_all(
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    _: None = Depends(require_roles("admin")),
):
    """
    Run all OneDrive exports in one call:
      1. DB backup (SQLite only)
      2. Shifts Excel export
      3. Inventory Excel export
    """
    _require_onedrive()
    result = SyncResult(ok=True)
    errors = []

    # 1. DB backup
    try:
        db_url = os.environ.get("DATABASE_URL", "sqlite:///./production_app.db")
        if "sqlite" in db_url:
            db_path = db_url.replace("sqlite:///", "").replace("sqlite://", "")
            candidates = [db_path, "./production_app.db", "production_app.db", "/app/production_app.db"]
            found = next((p for p in candidates if os.path.exists(p)), None)
            if found:
                with open(found, "rb") as f:
                    content = f.read()
                ts = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
                fname = f"production_app_{ts}.db"
                url = od.upload_file(f"{_FOLDER}/backups", fname, content)
                result.db_backup = url
    except Exception as e:
        errors.append(f"DB backup: {e}")

    # 2. Shifts Excel
    try:
        content = _build_shifts_excel(db)
        ts = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        fname = f"shifts_{ts}.xlsx"
        url = od.upload_file(
            f"{_FOLDER}/exports", fname, content,
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        )
        result.shifts_excel = url
    except Exception as e:
        errors.append(f"Shifts export: {e}")

    # 3. Inventory Excel
    try:
        content = _build_inventory_excel(db)
        ts = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        fname = f"inventory_{ts}.xlsx"
        url = od.upload_file(
            f"{_FOLDER}/exports", fname, content,
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        )
        result.inventory_excel = url
    except Exception as e:
        errors.append(f"Inventory export: {e}")

    result.errors = errors
    result.ok = len(errors) == 0
    return result
