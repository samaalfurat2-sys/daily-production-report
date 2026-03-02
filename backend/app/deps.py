import uuid
from typing import Generator, Set

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from app.database import SessionLocal
from app import models
from app.security import decode_token

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_current_user(db: Session = Depends(get_db), token: str = Depends(oauth2_scheme)) -> models.AppUser:
    try:
        payload = decode_token(token)
        user_id_str = payload.get("sub")
        if not user_id_str:
            raise ValueError("missing sub")
        # FIX: db.get() with Uuid(as_uuid=True) requires a uuid.UUID object,
        # not a plain string. Passing a str causes AttributeError: 'str' has no .hex
        user_id = uuid.UUID(user_id_str)
    except Exception:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    user = db.get(models.AppUser, user_id)
    if not user or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Inactive user")
    return user


def user_roles(user: models.AppUser) -> Set[str]:
    return {r.name for r in (user.roles or [])}


def require_roles(*required: str):
    required_set = set(required)

    def _checker(user: models.AppUser = Depends(get_current_user)) -> models.AppUser:
        roles = user_roles(user)
        if "admin" in roles:
            return user
        if not roles.intersection(required_set):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Insufficient role")
        return user

    return _checker


def require_unit_edit(unit_code: str):
    def _checker(db: Session = Depends(get_db), user: models.AppUser = Depends(get_current_user)) -> models.AppUser:
        roles = user_roles(user)
        if "admin" in roles or "supervisor" in roles:
            return user
        perm = db.query(models.UserUnitPermission).filter(
            models.UserUnitPermission.user_id == user.id,
            models.UserUnitPermission.unit_code == unit_code,
        ).first()
        if not perm or not perm.can_edit:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"No edit permission for unit: {unit_code}",
            )
        return user
    return _checker
