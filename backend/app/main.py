from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.database import Base, engine, SessionLocal
from app.routers.auth import router as auth_router
from app.routers.users import router as users_router
from app.routers.shifts import router as shifts_router
from app.routers.warehouses import router as warehouses_router
from app.routers.onedrive_sync import router as onedrive_router
from app.scripts.create_admin import ensure_roles_and_units, ensure_warehouses_and_items
from app import models  # noqa: F401 – ensure models are imported so Base sees them


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Run startup logic once, then yield for requests."""
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        ensure_roles_and_units(db)
        ensure_warehouses_and_items(db)
    finally:
        db.close()
    yield


app = FastAPI(
    title="Daily Production Report API",
    version="2.2.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list(),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    return {"ok": True, "app": "daily-production-report-api", "version": "2.2.0"}


app.include_router(auth_router)
app.include_router(users_router)
app.include_router(shifts_router)
app.include_router(warehouses_router)
app.include_router(onedrive_router)
