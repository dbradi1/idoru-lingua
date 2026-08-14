"""Idoru Lingua — FastAPI REST API layer.

Per Decision #28: FastAPI on port 5051, Tailscale-only binding.
Per Decision #9 amendment: split submit endpoints, session/active, skip, health.

All endpoints prefixed with /api/v1/.
Auth via Bearer token (except /health which is public per Decision #9).
Machine-readable error codes per Decision #9 amendment.
"""
import logging
import os
import time
import uuid
from pathlib import Path
from typing import Any

from fastapi import FastAPI, Request, HTTPException, UploadFile, File, Form, Depends, status
from fastapi.responses import FileResponse, JSONResponse
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, Field

from . import __version__
from .log_config import setup_logging, set_correlation_id, get_correlation_id
from .db import get_connection, init_db
from . import engine
from . import tts

logger = logging.getLogger(__name__)

# ─── Setup ───────────────────────────────────────────────────────────────────

setup_logging()
init_db()

app = FastAPI(
    title="Idoru Lingua API",
    version=__version__,
    docs_url="/docs",
    redoc_url="/redoc",
)

security = HTTPBearer(auto_error=False)

API_KEY = os.environ.get("LINGUA_API_KEY", "")

if not API_KEY:
    raise RuntimeError("LINGUA_API_KEY environment variable is not set — API cannot start without auth")


# ─── Auth middleware ──────────────────────────────────────────────────────────


async def verify_api_key(credentials: HTTPAuthorizationCredentials | None = Depends(security)) -> None:
    """Verify Bearer token. Skip for /health endpoint (handled separately)."""
    if not credentials or credentials.credentials != API_KEY:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": "Missing or invalid API key", "code": "UNAUTHORIZED"},
        )


# ─── Request middleware (correlation ID + logging) ────────────────────────────


@app.middleware("http")
async def request_middleware(request: Request, call_next):
    """Inject correlation ID and log every request."""
    req_id = uuid.uuid4().hex[:8]
    set_correlation_id(f"req={req_id}")

    start = time.monotonic()
    response = await call_next(request)
    elapsed = time.monotonic() - start

    logger.info(
        "%s %s → %d (%.0fms)",
        request.method,
        request.url.path,
        response.status_code,
        elapsed * 1000,
    )

    return response


# ─── Error handler ────────────────────────────────────────────────────────────


def error_response(code: str, message: str, status_code: int) -> JSONResponse:
    """Return a machine-readable error response per Decision #9."""
    logger.warning("Error response: %s — %s (HTTP %d)", code, message, status_code)
    return JSONResponse(
        status_code=status_code,
        content={"error": message, "code": code},
    )


# ─── Pydantic models ──────────────────────────────────────────────────────────


class TextSubmit(BaseModel):
    answer: str = Field(..., max_length=500, description="Typed answer")


class MCSubmit(BaseModel):
    selected_option: int = Field(..., ge=0, description="Selected option index")


class SettingsUpdate(BaseModel):
    daily_review_cap: int | None = None
    notification_time: str | None = None
    session_timeout_minutes: int | None = None
    audio_voice: str | None = None
    audio_rate: float | None = None


class SessionStart(BaseModel):
    card_ids: list[int] | None = None
    source: str = "on_demand"


# ─── Health (no auth) ──────────────────────────────────────────────────────────


@app.get("/api/v1/health")
async def health():
    """Liveness check. No auth required per Decision #9."""
    return {
        "status": "ok",
        "version": __version__,
        "azure_status": "reachable",  # TODO: cached check, 60s refresh
    }


# ─── Session management ───────────────────────────────────────────────────────


@app.get("/api/v1/session/due", dependencies=[Depends(verify_api_key)])
async def session_due():
    """Get due cards for today."""
    cards = engine.get_due_cards()
    return {"cards": cards}


@app.post("/api/v1/session/start", dependencies=[Depends(verify_api_key)])
async def session_start(body: SessionStart):
    """Start a new review session."""
    if body.card_ids is None:
        due = engine.get_due_cards()
        body.card_ids = [c["id"] for c in due]

    if not body.card_ids:
        return error_response("VALIDATION_ERROR", "No cards available for session", 422)

    result = engine.start_session(body.card_ids, source=body.source)
    return result


@app.get("/api/v1/session/active", dependencies=[Depends(verify_api_key)])
async def session_active():
    """Get the current active session (for app resume)."""
    return engine.get_active_session()


@app.post("/api/v1/session/{session_id}/submit/text", dependencies=[Depends(verify_api_key)])
async def submit_text(session_id: str, body: TextSubmit):
    """Submit a typed text answer."""
    try:
        return engine.submit_answer(session_id, body.answer, answer_type="text")
    except ValueError as e:
        msg = str(e)
        if "not found" in msg:
            return error_response("SESSION_NOT_FOUND", msg, 404)
        if "not active" in msg:
            return error_response("SESSION_NOT_ACTIVE", msg, 409)
        return error_response("VALIDATION_ERROR", msg, 422)


@app.post("/api/v1/session/{session_id}/submit/mc", dependencies=[Depends(verify_api_key)])
async def submit_mc(session_id: str, body: MCSubmit):
    """Submit a multiple choice answer."""
    try:
        return engine.submit_answer(session_id, body.selected_option, answer_type="mc")
    except ValueError as e:
        msg = str(e)
        if "not found" in msg:
            return error_response("SESSION_NOT_FOUND", msg, 404)
        if "not active" in msg:
            return error_response("SESSION_NOT_ACTIVE", msg, 409)
        return error_response("VALIDATION_ERROR", msg, 422)


@app.post("/api/v1/session/{session_id}/submit/audio", dependencies=[Depends(verify_api_key)])
async def submit_audio(
    session_id: str,
    audio: UploadFile = File(...),
    duration: float | None = Form(None),
):
    """Submit a spoken answer (multipart upload)."""
    # Validate file size
    max_size = 10 * 1024 * 1024  # 10 MB
    content = await audio.read()
    if len(content) > max_size:
        return error_response("AUDIO_TOO_LARGE", "Audio file exceeds 10 MB limit", 413)

    # Validate format
    allowed_types = {"audio/m4a", "audio/x-m4a", "audio/wav", "audio/wave", "audio/mpeg", "audio/mp3"}
    if audio.content_type and audio.content_type not in allowed_types:
        return error_response("UNSUPPORTED_AUDIO_FORMAT", "Supported: m4a, wav, mp3", 415)

    # TODO: Full pronunciation assessment via Azure
    # Return 501 until pronunciation scoring is implemented — don't silently grade as "again"
    return error_response(
        "INTERNAL_ERROR",
        "Audio pronunciation scoring not yet implemented",
        501,
    )


@app.post("/api/v1/session/{session_id}/skip", dependencies=[Depends(verify_api_key)])
async def skip_card(session_id: str):
    """Skip the current card — FSRS-neutral, just advance the queue."""
    try:
        return engine.skip_card(session_id)
    except ValueError as e:
        msg = str(e)
        if "not found" in msg:
            return error_response("SESSION_NOT_FOUND", msg, 404)
        if "not active" in msg:
            return error_response("SESSION_NOT_ACTIVE", msg, 409)
        return error_response("VALIDATION_ERROR", msg, 422)


@app.post("/api/v1/session/{session_id}/undo", dependencies=[Depends(verify_api_key)])
async def undo_rating(session_id: str):
    """Undo the last rating in a session."""
    success = engine.undo_last_rating(session_id)
    if not success:
        return error_response("VALIDATION_ERROR", "No rating to undo", 422)
    return {"undone": True}


@app.post("/api/v1/session/{session_id}/end", dependencies=[Depends(verify_api_key)])
async def end_session(session_id: str):
    """End a session manually. Returns summary stats."""
    try:
        return engine.end_session(session_id)
    except ValueError as e:
        return error_response("SESSION_NOT_FOUND", str(e), 404)


# ─── Card interaction ──────────────────────────────────────────────────────────


@app.get("/api/v1/card/{card_id}/audio", dependencies=[Depends(verify_api_key)])
async def get_card_audio(card_id: int):
    """Serve cached .m4a audio file. Generates on-the-fly if missing (lazy TTS per #30)."""
    try:
        audio_path = tts.get_card_audio(card_id)
        return FileResponse(str(audio_path), media_type="audio/m4a")
    except ValueError as e:
        return error_response("CARD_NOT_FOUND", str(e), 404)
    except TimeoutError:
        return error_response("AUDIO_UNAVAILABLE", "Azure TTS timed out — try again", 503)
    except Exception as e:
        logger.error("Audio generation failed (card_id=%s): %s", card_id, e, exc_info=True)
        return error_response("AUDIO_UNAVAILABLE", "Audio generation failed", 503)


@app.get("/api/v1/card/{card_id}/explain", dependencies=[Depends(verify_api_key)])
async def explain_card(card_id: int):
    """Get grammar note for a card (spiega feature per #22)."""
    try:
        note = engine.get_card_explanation(card_id)
        return {"card_id": card_id, "grammar_note": note}
    except ValueError as e:
        return error_response("CARD_NOT_FOUND", str(e), 404)


@app.post("/api/v1/pronunciation/assess", dependencies=[Depends(verify_api_key)])
async def assess_pronunciation(
    audio: UploadFile = File(...),
    reference_text: str = Form(...),
):
    """Assess pronunciation. Upload audio + reference text, returns phoneme scores."""
    # Validate file size
    max_size = 10 * 1024 * 1024
    content = await audio.read()
    if len(content) > max_size:
        return error_response("AUDIO_TOO_LARGE", "Audio file exceeds 10 MB limit", 413)

    # Save to temp file
    import tempfile
    with tempfile.NamedTemporaryFile(suffix=".m4a", delete=False) as tmp:
        tmp.write(content)
        tmp_path = tmp.name

    try:
        result = engine.assess_pronunciation(tmp_path, reference_text)
        return result
    except NotImplementedError:
        return error_response("INTERNAL_ERROR", "Pronunciation assessment not yet implemented", 500)
    except TimeoutError:
        return error_response("AZURE_TIMEOUT", "Azure pronunciation scoring timed out", 504)
    except Exception as e:
        logger.error("Pronunciation assessment failed: %s", e, exc_info=True)
        return error_response("AZURE_ERROR", str(e), 502)
    finally:
        os.unlink(tmp_path)


# ─── Progression ──────────────────────────────────────────────────────────────


@app.get("/api/v1/progress/overview", dependencies=[Depends(verify_api_key)])
async def progress_overview():
    """Overall stats, current city, Memory Strength."""
    cities = engine.get_city_progress()
    return {"cities": cities}


@app.get("/api/v1/progress/city/{city_id}", dependencies=[Depends(verify_api_key)])
async def progress_city(city_id: int):
    """City detail with cluster breakdown."""
    clusters = engine.get_cluster_strength(city_id)
    return {"city_id": city_id, "clusters": clusters}


@app.get("/api/v1/progress/clusters/{city_id}", dependencies=[Depends(verify_api_key)])
async def progress_clusters(city_id: int):
    """Cluster strengths for a city."""
    clusters = engine.get_cluster_strength(city_id)
    return {"city_id": city_id, "clusters": clusters}


# ─── Stats ────────────────────────────────────────────────────────────────────


@app.get("/api/v1/stats/retention", dependencies=[Depends(verify_api_key)])
async def stats_retention(range: int = 30):
    """Retention curve data points."""
    return {"data": engine.get_stats_retention(range)}


@app.get("/api/v1/stats/history", dependencies=[Depends(verify_api_key)])
async def stats_history(range: int = 30):
    """Daily review counts."""
    return {"data": engine.get_stats_history(range)}


@app.get("/api/v1/stats/leeches", dependencies=[Depends(verify_api_key)])
async def stats_leeches():
    """Leech queue contents."""
    return {"leeches": engine.get_leeches()}


# ─── Practice ──────────────────────────────────────────────────────────────────


@app.get("/api/v1/practice/quiz", dependencies=[Depends(verify_api_key)])
async def practice_quiz():
    """On-demand due cards (not tied to morning push)."""
    cards = engine.get_due_cards()
    return {"cards": cards}


@app.get("/api/v1/practice/free/{city_id}", dependencies=[Depends(verify_api_key)])
async def practice_free(city_id: int):
    """Browse cards without FSRS grading (casual review)."""
    conn = get_connection()
    try:
        from .db import query_all
        rows = query_all(
            conn,
            "SELECT * FROM cards WHERE cluster_id IN "
            "(SELECT id FROM clusters WHERE city_id = ?) AND import_validated = 1",
            (city_id,),
        )
        return {"cards": [dict(r) for r in rows]}
    finally:
        conn.close()


# ─── Settings ──────────────────────────────────────────────────────────────────


@app.get("/api/v1/settings", dependencies=[Depends(verify_api_key)])
async def get_settings():
    """Get server-side settings."""
    return engine.get_settings()


@app.patch("/api/v1/settings", dependencies=[Depends(verify_api_key)])
async def update_settings(body: SettingsUpdate):
    """Update server-side settings."""
    updates = body.model_dump(exclude_none=True)
    return engine.update_settings(updates)