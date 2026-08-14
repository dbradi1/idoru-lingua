"""Idoru Lingua — Logging configuration.

Built per LOGGING.md spec. Single setup_logging() call at app startup
configures file + console handlers with correlation IDs.
"""
import logging
import logging.handlers
import os
from contextvars import ContextVar

# Correlation ID context variable — set per session/request
correlation_id_var: ContextVar[str] = ContextVar("correlation_id", default="—")

LOG_DIR = os.environ.get("LINGUA_LOG_DIR", "/home/drew/lingua-logs")


class CorrelationFilter(logging.Filter):
    """Injects correlation_id from context var into every log record."""

    def filter(self, record: logging.LogRecord) -> bool:
        if not hasattr(record, "correlation_id"):
            record.correlation_id = correlation_id_var.get()
        return True


def setup_logging(level: int = logging.DEBUG) -> None:
    """Call once at app startup. Configures all handlers for the 'lingua' logger."""
    os.makedirs(LOG_DIR, exist_ok=True)

    formatter = logging.Formatter(
        fmt="%(asctime)s | %(name)s | %(levelname)s | %(correlation_id)s | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    # File handler — daily rotation, 7-day retention
    file_handler = logging.handlers.TimedRotatingFileHandler(
        filename=os.path.join(LOG_DIR, "lingua.log"),
        when="midnight",
        backupCount=7,
    )
    file_handler.setLevel(level)
    file_handler.setFormatter(formatter)
    file_handler.addFilter(CorrelationFilter())

    # Console handler — INFO minimum (DEBUG stays in files only)
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(formatter)
    console_handler.addFilter(CorrelationFilter())

    root = logging.getLogger("lingua")
    root.setLevel(level)
    root.addHandler(file_handler)
    root.addHandler(console_handler)

    # Suppress noisy third-party loggers
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("httpx").setLevel(logging.WARNING)
    logging.getLogger("azure").setLevel(logging.WARNING)

    root.info("Logging initialized (level=%s, dir=%s)", logging.getLevelName(level), LOG_DIR)


def set_correlation_id(correlation_id: str) -> None:
    """Set the correlation ID for the current async context."""
    correlation_id_var.set(correlation_id)


def get_correlation_id() -> str:
    """Get the current correlation ID."""
    return correlation_id_var.get()