"""Idoru Lingua — Database connection and schema management.

SQLite with WAL mode + busy_timeout. Single connection per operation
(sqlite3 in Python is thread-safe with check_same_thread=False for FastAPI).
"""
import json
import logging
import os
import sqlite3
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)

DB_PATH = os.environ.get("LINGUA_DB_PATH", "/home/drew/lingua-data/lingua.db")
SCHEMA_PATH = Path(__file__).parent.parent / "schema.sql"


def get_connection(db_path: str | None = None) -> sqlite3.Connection:
    """Get a SQLite connection with pragmas applied."""
    path = db_path or DB_PATH
    conn = sqlite3.connect(path, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode = WAL;")
    conn.execute("PRAGMA busy_timeout = 5000;")
    conn.execute("PRAGMA foreign_keys = ON;")
    return conn


def init_db(db_path: str | None = None) -> None:
    """Initialize the database from schema.sql. Safe to call repeatedly (uses IF NOT EXISTS)."""
    path = db_path or DB_PATH
    Path(path).parent.mkdir(parents=True, exist_ok=True)

    logger.info("Initializing database (path=%s)", path)

    schema_sql = SCHEMA_PATH.read_text()

    conn = get_connection(path)
    try:
        conn.executescript(schema_sql)
        conn.commit()
        logger.info("Database schema applied successfully")
    except Exception as e:
        logger.error("Failed to apply schema: %s", e, exc_info=True)
        raise
    finally:
        conn.close()


# ─── Query helpers ───────────────────────────────────────────────────────────


def query_one(conn: sqlite3.Connection, sql: str, params: tuple = ()) -> sqlite3.Row | None:
    """Execute a query and return a single row (or None)."""
    return conn.execute(sql, params).fetchone()


def query_all(conn: sqlite3.Connection, sql: str, params: tuple = ()) -> list[sqlite3.Row]:
    """Execute a query and return all rows."""
    return conn.execute(sql, params).fetchall()


def execute(conn: sqlite3.Connection, sql: str, params: tuple = ()) -> sqlite3.Cursor:
    """Execute a statement and return cursor (call conn.commit() after)."""
    return conn.execute(sql, params)