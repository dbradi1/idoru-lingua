# Idoru Lingua — Logging Specification

## Philosophy

Logging is built in from the first line of code, not retrofitted. When something breaks at 3 AM, we read the log — we don't reproduce the issue.

## Framework

Python stdlib `logging` module. No external dependency required.

- **Logger name convention:** `lingua.<module>` (e.g., `lingua.engine`, `lingua.api`, `lingua.import`, `lingua.tts`)
- Each module creates its logger at the top: `logger = logging.getLogger(__name__)`
- A single `setup_logging()` function in `lingua/log_config.py` configures all handlers, formatters, and levels — called once at app startup

## Log Format

```
2026-08-14 10:22:39 | lingua.engine | INFO | session=42 | Reviewing card 187 (rating=good)
```

| Field | Source | Purpose |
|-------|--------|---------|
| Timestamp | `%(asctime)s` | When it happened |
| Module | `%(name)s` | Which component |
| Level | `%(levelname)s` | Severity |
| Correlation ID | Custom filter | Trace an entire flow (session ID, request ID) |
| Message | `%(message)s` | What happened |

### Correlation IDs

The single most important debugging tool. Every log line within a session or API request includes a correlation ID so you can `grep session=42` and see the entire flow end-to-end.

- **Session-based code:** `session=<id>` (e.g., `session=42`)
- **API requests:** `req=<uuid8>` (short UUID, first 8 chars)
- **Cron/pre-warm:** `job=prewarm-20260814` (job name + date)

Implemented via a `logging.Filter` that injects the correlation ID from a context variable (`contextvars`) or is passed explicitly to the logger.

## Log Levels

| Level | When to use | Examples |
|-------|-------------|---------|
| **INFO** | Session start/stop, card reviewed, pre-warm triggered, API requests, user-facing state changes | `Session 42 started (source=morning_cron, cards=20)` |
| **DEBUG** | FSRS state transitions, card queue construction, TTS generation details, internal decisions | `FSRS review: card=187 stability=2.14→2.31 difficulty=0.12→0.10` |
| **WARNING** | Recoverable issues, degraded behavior, fallbacks | `TTS fresh generation failed (timeout), using cached audio for card 187` |
| **ERROR** | Failures that impact the user or require attention | `Azure Speech API timeout after 15s for card 187` |
| **CRITICAL** | App cannot function | `Database write failed: disk full` |

### Rules

- Every function that handles a user-facing action logs **entry + exit** at INFO or DEBUG
- Every `except` block logs the exception **with context** (not just the traceback): `logger.error("Failed to generate TTS for card %s: %s", card_id, e, exc_info=True)`
- Never log raw secrets, API keys, or auth tokens
- Log the **outcome**, not just the intent: `Session 42 completed (good=15, hard=3, again=2)` not just `Session 42 starting`

## Log Output

### File logging (primary)

- **Location:** `/home/drew/lingua-logs/`
- **Rotation:** Daily (`TimedRotatingFileHandler`, `when='midnight'`)
- **Retention:** 7 days (`backupCount=7`)
- **Filename:** `lingua-YYYY-MM-DD.log`
- **Level:** DEBUG (everything goes to file; filter at read time)

### Console logging (secondary)

- **Stream:** stdout
- **Level:** INFO (DEBUG stays in files only)
- **Format:** Same as file, minus the timestamp (console output is already real-time)

### Why not just stdout?

FastAPI runs under systemd or uvicorn in production. Stdout goes to journald, which is fine for quick checks, but file logging gives us:
- Easy `grep` without `journalctl` syntax
- Persistent history independent of service restarts
- Clean rotation without log growth
- Portability if we move off systemd

## Module-Level Conventions

### `lingua.engine` (review engine)
- INFO: session start, each card review (card_id, rating), session end with summary stats
- DEBUG: FSRS state before/after, queue construction, leech detection logic

### `lingua.api` (FastAPI REST layer)
- INFO: each request (method, path, status, duration)
- DEBUG: request body for non-GET (truncated), response payload (truncated)
- WARNING: auth failures, rate limit hits
- ERROR: 500 responses with stack trace

### `lingua.tts` (Azure Speech)
- INFO: TTS generation started/completed (card_id, duration_ms)
- DEBUG: Azure API request parameters, phoneme scores
- WARNING: fallback to cached audio, partial failure
- ERROR: Azure API timeout, auth failure, unhandled Azure error

### `lingua.import` (Anki import / validation)
- INFO: import started (source, count), validation results, import completed
- DEBUG: per-card validation details
- WARNING: skipped cards with reason, duplicate detection
- ERROR: import file unreadable, schema mismatch

### `lingua.prewarm` (pre-warm pipeline)
- INFO: pre-warm started (cards_due), completed (generated, skipped, duration)
- DEBUG: per-card pre-warm status
- WARNING: partial failure, timeout
- ERROR: pre-warm aborted

## Example Implementation

### `lingua/log_config.py`

```python
import logging
import logging.handlers
import os
from datetime import datetime

LOG_DIR = "/home/drew/lingua-logs"

class CorrelationFilter(logging.Filter):
    """Injects correlation_id into log records if not already present."""
    def __init__(self, correlation_id="—"):
        super().__init__()
        self.correlation_id = correlation_id

    def filter(self, record):
        if not hasattr(record, "correlation_id"):
            record.correlation_id = self.correlation_id
        return True

def setup_logging(correlation_id="—", level=logging.DEBUG):
    """Call once at app startup."""
    os.makedirs(LOG_DIR, exist_ok=True)

    formatter = logging.Formatter(
        fmt="%(asctime)s | %(name)s | %(levelname)s | %(correlation_id)s | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    )

    # File handler — daily rotation, 7-day retention
    file_handler = logging.handlers.TimedRotatingFileHandler(
        filename=os.path.join(LOG_DIR, "lingua.log"),
        when="midnight",
        backupCount=7,
    )
    file_handler.setLevel(level)
    file_handler.setFormatter(formatter)
    file_handler.addFilter(CorrelationFilter(correlation_id))

    # Console handler — INFO minimum
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(formatter)
    console_handler.addFilter(CorrelationFilter(correlation_id))

    root = logging.getLogger("lingua")
    root.setLevel(level)
    root.addHandler(file_handler)
    root.addHandler(console_handler)

    # Suppress noisy third-party loggers
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("httpx").setLevel(logging.WARNING)
```

### Usage in a module

```python
import logging
from lingua.log_config import setup_logging

logger = logging.getLogger(__name__)

def review_card(card_id: int, rating: str, session_id: int):
    logger.info("Reviewing card %d (rating=%s)", card_id, rating,
                extra={"correlation_id": f"session={session_id}"})
    try:
        # ... review logic ...
        logger.debug("FSRS updated: card=%d next_review=%s", card_id, next_review)
    except Exception as e:
        logger.error("Review failed for card %d: %s", card_id, e, exc_info=True)
        raise
```

## What Not to Log

- API keys, auth tokens, passwords
- Full audio file contents (log the path and duration, not the bytes)
- Full session card arrays on every log line (log the count and current index)
- Personally identifying info from Anki decks (log card IDs, not card content)