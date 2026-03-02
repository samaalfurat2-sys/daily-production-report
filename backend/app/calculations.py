from __future__ import annotations

from typing import Optional, Dict, Any


def _to_float(x) -> Optional[float]:
    if x is None:
        return None
    try:
        return float(x)
    except Exception:
        return None


def _nz(x) -> float:
    v = _to_float(x)
    return v if v is not None else 0.0


def _nzi(x) -> int:
    return int(x) if x is not None else 0


def blow_calc(blow: Any) -> Dict[str, Any]:
    if blow is None:
        return {}
    preforms_per_carton = int(getattr(blow, "preforms_per_carton", 1248) or 1248)
    prev_cartons = _nz(getattr(blow, "prev_cartons", None))
    rec_cartons = _nz(getattr(blow, "received_cartons", None))
    next_cartons = _nz(getattr(blow, "next_cartons", None))
    product_cartons = _nz(getattr(blow, "product_cartons", None))
    consumed_cartons = prev_cartons + rec_cartons - next_cartons
    consumed_preforms = consumed_cartons * preforms_per_carton
    product_pcs = product_cartons * 20.0
    waste_total_pcs = _nzi(getattr(blow, "waste_preforms_pcs", None)) + _nzi(getattr(blow, "waste_scrap_pcs", None)) + _nzi(getattr(blow, "waste_bottles_pcs", None))
    variance_pcs = product_pcs + waste_total_pcs - consumed_preforms
    variance_cartons = variance_pcs / preforms_per_carton if preforms_per_carton else None
    waste_pct = (waste_total_pcs / product_pcs) if product_pcs else None
    shortage_pct = (variance_pcs / product_pcs) if product_pcs else None
    return {
        "consumed_cartons": consumed_cartons,
        "consumed_preforms_pcs": consumed_preforms,
        "product_pcs": product_pcs,
        "waste_total_pcs": waste_total_pcs,
        "variance_pcs": variance_pcs,
        "variance_cartons": variance_cartons,
        "waste_pct": waste_pct,
        "shortage_pct": shortage_pct,
    }


def filling_calc(filling: Any, blow: Any) -> Dict[str, Any]:
    if filling is None:
        return {}
    caps_per_carton = int(getattr(filling, "caps_per_carton", 5500) or 5500)
    prev_cartons = _nz(getattr(filling, "prev_cartons", None))
    rec_cartons = _nz(getattr(filling, "received_cartons", None))
    next_cartons = _nz(getattr(filling, "next_cartons", None))
    consumed_cartons = prev_cartons + rec_cartons - next_cartons
    consumed_caps = consumed_cartons * caps_per_carton
    blow_product_cartons = _nz(getattr(blow, "product_cartons", None)) if blow is not None else 0.0
    product_caps = blow_product_cartons * 20.0
    waste_total = _nzi(getattr(filling, "waste_caps_pcs", None)) + _nzi(getattr(filling, "waste_scrap_pcs", None)) + _nzi(getattr(filling, "waste_bottles_pcs", None))
    variance_caps = product_caps + waste_total - consumed_caps
    variance_cartons = variance_caps / caps_per_carton if caps_per_carton else None
    waste_pct = (waste_total / product_caps) if product_caps else None
    shortage_pct = (variance_caps / product_caps) if product_caps else None
    return {
        "consumed_cartons": consumed_cartons,
        "consumed_caps": consumed_caps,
        "product_caps": product_caps,
        "waste_total_pcs": waste_total,
        "variance_caps": variance_caps,
        "variance_cartons": variance_cartons,
        "waste_pct": waste_pct,
        "shortage_pct": shortage_pct,
    }


def label_calc(label: Any, blow: Any) -> Dict[str, Any]:
    if label is None:
        return {}
    labels_per_roll = int(getattr(label, "labels_per_roll", 23000) or 23000)
    prev_rolls = _nz(getattr(label, "prev_rolls", None))
    rec_rolls = _nz(getattr(label, "received_rolls", None))
    next_rolls = _nz(getattr(label, "next_rolls", None))
    consumed_rolls = prev_rolls + rec_rolls - next_rolls
    consumed_labels = consumed_rolls * labels_per_roll
    blow_product_cartons = _nz(getattr(blow, "product_cartons", None)) if blow is not None else 0.0
    product_labels = blow_product_cartons * 20.0
    waste_grams = _nz(getattr(label, "waste_grams", None))
    waste_labels = waste_grams / 35.0 if waste_grams else 0.0
    variance_labels = product_labels - consumed_labels + waste_labels
    variance_rolls = variance_labels / labels_per_roll if labels_per_roll else None
    waste_pct = (waste_labels / product_labels) if product_labels else None
    shortage_pct = (variance_labels / product_labels) if product_labels else None
    return {
        "consumed_rolls": consumed_rolls,
        "consumed_labels": consumed_labels,
        "product_labels": product_labels,
        "waste_grams": waste_grams,
        "waste_labels": waste_labels,
        "variance_labels": variance_labels,
        "variance_rolls": variance_rolls,
        "waste_pct": waste_pct,
        "shortage_pct": shortage_pct,
    }


def shrink_calc(shrink: Any, blow: Any) -> Dict[str, Any]:
    if shrink is None:
        return {}
    kg_per_roll = _nz(getattr(shrink, "kg_per_roll", None)) or 25.0
    kg_per_carton = _nz(getattr(shrink, "kg_per_carton", None)) or 0.055
    prev_rolls = _nz(getattr(shrink, "prev_rolls", None))
    rec_rolls = _nz(getattr(shrink, "received_rolls", None))
    next_rolls = _nz(getattr(shrink, "next_rolls", None))
    consumed_rolls = prev_rolls + rec_rolls - next_rolls
    consumed_kg = consumed_rolls * kg_per_roll
    blow_product_cartons = _nz(getattr(blow, "product_cartons", None)) if blow is not None else 0.0
    product_kg = blow_product_cartons * kg_per_carton
    waste_kg = _nz(getattr(shrink, "waste_kg", None))
    waste_cartons = (waste_kg / 55.0) if waste_kg else 0.0
    variance_kg = product_kg + waste_kg - consumed_kg
    variance_cartons = variance_kg / 24.0
    waste_pct = (waste_kg / product_kg) if product_kg else None
    shortage_pct = (variance_kg / product_kg) if product_kg else None
    bottles_equivalent = (consumed_kg / kg_per_carton) * 20.0 if kg_per_carton else None
    return {
        "consumed_rolls": consumed_rolls,
        "consumed_kg": consumed_kg,
        "product_kg": product_kg,
        "waste_kg": waste_kg,
        "waste_cartons": waste_cartons,
        "variance_kg": variance_kg,
        "variance_cartons": variance_cartons,
        "waste_pct": waste_pct,
        "shortage_pct": shortage_pct,
        "bottles_equivalent": bottles_equivalent,
    }


def diesel_calc(diesel: Any, prev_balance: Optional[float] = None) -> Dict[str, Any]:
    if diesel is None:
        return {}
    g1 = _nz(getattr(diesel, "generator1_consumed", None))
    g2 = _nz(getattr(diesel, "generator2_consumed", None))
    total_usage = g1 + g2
    received = _nz(getattr(diesel, "main_tank_received", None))
    balance = prev_balance + received - total_usage if prev_balance is not None else None
    return {"total_usage": total_usage, "main_tank_balance": balance}


def shift_computed(shift: Any) -> Dict[str, Any]:
    blow = getattr(shift, "blow", None)
    filling = getattr(shift, "filling", None)
    label = getattr(shift, "label", None)
    shrink = getattr(shift, "shrink", None)
    diesel = getattr(shift, "diesel", None)

    blow_c = blow_calc(blow)
    filling_c = filling_calc(filling, blow)
    label_c = label_calc(label, blow)
    shrink_c = shrink_calc(shrink, blow)
    diesel_c = diesel_calc(diesel)

    summary = {
        "blow_consumed_cartons": blow_c.get("consumed_cartons"),
        "blow_consumed_preforms": blow_c.get("consumed_preforms_pcs"),
        "filling_consumed_cartons": filling_c.get("consumed_cartons"),
        "filling_consumed_caps": filling_c.get("consumed_caps"),
        "label_consumed_rolls": label_c.get("consumed_rolls"),
        "label_consumed_labels": label_c.get("consumed_labels"),
        "shrink_consumed_rolls": shrink_c.get("consumed_rolls"),
        "shrink_consumed_kg": shrink_c.get("consumed_kg"),
        "diesel_total_usage": diesel_c.get("total_usage"),
        "finished_cartons_total": _nz(getattr(blow, "product_cartons", None)) if blow is not None else 0.0,
    }

    return {
        "blow": blow_c,
        "filling": filling_c,
        "label": label_c,
        "shrink": shrink_c,
        "diesel": diesel_c,
        "summary": summary,
    }
