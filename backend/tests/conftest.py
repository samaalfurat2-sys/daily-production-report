"""
Pytest configuration — sets environment variables BEFORE any app import.

This file is loaded by pytest before test collection, so DATABASE_URL etc.
are in place when app.database creates its SQLAlchemy engine.
"""
import os
import tempfile
import pytest

# Use a temp-file SQLite DB (avoids the in-memory multi-connection isolation issue)
_TEST_DB_FILE = os.path.join(tempfile.gettempdir(), "test_production_app.db")

os.environ["DATABASE_URL"] = f"sqlite:///{_TEST_DB_FILE}"
os.environ["JWT_SECRET"] = "test-secret-do-not-use-in-prod"
os.environ["ALLOW_DEMO_SEED"] = "yes"


@pytest.fixture(scope="session", autouse=True)
def cleanup_test_db():
    """Remove the test DB file after the full test session."""
    yield
    try:
        os.remove(_TEST_DB_FILE)
    except FileNotFoundError:
        pass
