from __future__ import annotations

from typing import List, Optional
import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.deps import get_db, get_current_user, require_roles, user_roles
from app import models
from app.schemas import UserInfo
from app.security import hash_password
from pydantic import BaseModel
from typing import Dict

router = APIRouter(tags=["users"])


@router.get("/me", response_model=UserInfo)
def me(db: Session = Depends(get_db), user: models.AppUser = Depends(get_current_user)):
    """Return the authenticated user's profile, roles and unit permissions."""
    roles = sorted(list(user_roles(user)))
    perms = {p.unit_code: bool(p.can_edit) for p in (user.unit_permissions or [])}
    return UserInfo(
        id=user.id,
        username=user.username,
        full_name=user.full_name,
        preferred_locale=user.preferred_locale,
        roles=roles,
        unit_permissions=perms,
    )


class CreateUserRequest(BaseModel):
    username: str
    password: str
    full_name: Optional[str] = None
    preferred_locale: str = "ar"
    roles: List[str] = []
    unit_permissions: Dict[str, bool] = {}


@router.post("/users", response_model=UserInfo)
def create_user(
    payload: CreateUserRequest,
    db: Session = Depends(get_db),
    _: models.AppUser = Depends(require_roles("admin")),
):
    if db.query(models.AppUser).filter(models.AppUser.username == payload.username).first():
        raise HTTPException(status_code=400, detail="Username already exists")

    user = models.AppUser(
        username=payload.username,
        full_name=payload.full_name,
        preferred_locale=payload.preferred_locale or "ar",
        password_hash=hash_password(payload.password),
        is_active=True,
    )
    db.add(user)
    db.flush()

    for role_name in payload.roles:
        role = db.query(models.Role).filter(models.Role.name == role_name).first()
        if role:
            user.roles.append(role)

    for unit_code, can_edit in (payload.unit_permissions or {}).items():
        db.add(models.UserUnitPermission(user_id=user.id, unit_code=unit_code, can_edit=bool(can_edit)))

    db.commit()
    db.refresh(user)

    roles_out = sorted(list(user_roles(user)))
    perms_out = {p.unit_code: bool(p.can_edit) for p in (user.unit_permissions or [])}
    return UserInfo(
        id=user.id,
        username=user.username,
        full_name=user.full_name,
        preferred_locale=user.preferred_locale,
        roles=roles_out,
        unit_permissions=perms_out,
    )


@router.get("/users", response_model=List[UserInfo])
def list_users(
    db: Session = Depends(get_db),
    _: models.AppUser = Depends(require_roles("admin", "supervisor")),
):
    """List all users (admin / supervisor only)."""
    users = db.query(models.AppUser).order_by(models.AppUser.username).all()
    result = []
    for u in users:
        roles_out = sorted(list(user_roles(u)))
        perms_out = {p.unit_code: bool(p.can_edit) for p in (u.unit_permissions or [])}
        result.append(
            UserInfo(
                id=u.id,
                username=u.username,
                full_name=u.full_name,
                preferred_locale=u.preferred_locale,
                roles=roles_out,
                unit_permissions=perms_out,
            )
        )
    return result
