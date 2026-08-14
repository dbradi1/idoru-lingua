"""Idoru Lingua — Core review engine.

FSRS-based spaced repetition with session management.
All functions are card_id-based per Decision #24; the API layer
translates session_id-based calls to these functions per Decision #9.

Per Decision #30 (Issue #10):
- get_card_audio() delegates to lingua.tts for lazy generation
"""
import json
import logging
import os
import sqlite3
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from fsrs import Card as FSRSCard
from fsrs import Rating
from fsrs import Scheduler

from .db import get_connection, query_one, query_all, execute

logger = logging.getLogger(__name__)


# ─── Helpers ─────────────────────────────────────────────────────────────────


def _now_iso() -> str:
    """Return current time as ISO 8601 string."""
    return datetime.now(timezone.utc).isoformat()


def _gen_session_id() -> str:
    """Generate a session ID."""
    return f"sess_{uuid.uuid4().hex[:12]}"


def _card_to_dict(row: sqlite3.Row) -> dict:
    """Convert a card row to a dict suitable for API response."""
    return {
        "id": row["id"],
        "cluster_id": row["cluster_id"],
        "card_type": row["card_type"],
        "italian_text": row["italian_text"],
        "english_text": row["english_text"],
        "grammar_note": row["grammar_note"] if "grammar_note" in row.keys() else None,
        "audio_path": row["audio_path"] if "audio_path" in row.keys() else None,
    }


# ─── Session management (thin mapper per Decision #9 Option A) ───────────────


def get_due_cards(user_id: int = 1, limit: int = 20) -> list[dict]:
    """Get due cards for today, sorted by cluster weakness (weakest first).

    Returns list of card dicts.
    """
    logger.info("get_due_cards (user_id=%s, limit=%s)", user_id, limit)

    conn = get_connection()
    try:
        rows = query_all(
            conn,
            """
            SELECT c.* FROM cards c
            WHERE c.fsrs_next_review IS NULL
               OR c.fsrs_next_review <= ?
            AND c.import_validated = 1
            AND c.audio_status != 'failed'
            ORDER BY c.fsrs_next_review ASC
            LIMIT ?
            """,
            (_now_iso(), limit),
        )
        cards = [_card_to_dict(r) for r in rows]
        logger.info("get_due_cards returned %d cards", len(cards))
        return cards
    finally:
        conn.close()


def start_session(card_ids: list[int], source: str = "morning_cron", user_id: int = 1) -> dict:
    """Start a new session. Creates a row in sessions table.

    Returns: { session_id, total_cards, first_card }
    """
    session_id = _gen_session_id()
    now = _now_iso()
    card_ids_json = json.dumps(card_ids)

    logger.info("start_session (session_id=%s, cards=%d, source=%s)", session_id, len(card_ids), source)

    conn = get_connection()
    try:
        execute(
            conn,
            """
            INSERT INTO sessions (id, user_id, card_ids_json, current_index, cards_completed,
                                  status, source, total_cards, started_at, created_at)
            VALUES (?, ?, ?, 0, 0, 'in_progress', ?, ?, ?, ?)
            """,
            (session_id, user_id, card_ids_json, source, len(card_ids), now, now),
        )
        conn.commit()

        first_card = _get_session_card(session_id, 0, conn)
        logger.info("Session started (session_id=%s, first_card=%s)", session_id, first_card["id"] if first_card else None)

        return {
            "session_id": session_id,
            "total_cards": len(card_ids),
            "first_card": first_card,
        }
    finally:
        conn.close()


def get_active_session(user_id: int = 1) -> dict | None:
    """Get the current active session (if any). For app resume per Decision #9.

    Returns: { session, current_card } or { session: None, current_card: None }
    """
    logger.info("get_active_session (user_id=%s)", user_id)

    conn = get_connection()
    try:
        row = query_one(
            conn,
            """
            SELECT * FROM sessions
            WHERE user_id = ? AND status = 'in_progress'
            ORDER BY created_at DESC LIMIT 1
            """,
            (user_id,),
        )

        if row is None:
            logger.info("No active session found")
            return {"session": None, "current_card": None}

        session = {
            "id": row["id"],
            "started_at": row["started_at"],
            "cards_total": row["total_cards"],
            "cards_completed": row["cards_completed"],
            "status": row["status"],
        }

        current_card = _get_session_card(row["id"], row["current_index"], conn)
        logger.info("Active session found (session_id=%s, completed=%d/%d)",
                    row["id"], row["cards_completed"], row["total_cards"])

        return {"session": session, "current_card": current_card}
    finally:
        conn.close()


def submit_answer(session_id: str, answer: str | int | None, answer_type: str = "text",
                  pronunciation_score: dict | None = None) -> dict:
    """Submit an answer for the current card in a session.

    Grades the card via FSRS, advances the session queue, returns grade + next card.

    answer_type: 'text' | 'mc' | 'audio'
    For 'mc': answer is the selected option index (int)
    For 'text': answer is the typed string
    For 'audio': answer is None (pronunciation_score carries the result)

    Returns: { card_id, grade, next_interval, correct_option?, pronunciation?, next_card }
    """
    logger.info("submit_answer (session_id=%s, type=%s)", session_id, answer_type)

    conn = get_connection()
    try:
        session = query_one(conn, "SELECT * FROM sessions WHERE id = ?", (session_id,))
        if session is None:
            raise ValueError(f"Session {session_id} not found")
        if session["status"] != "in_progress":
            raise ValueError(f"Session {session_id} is not active (status={session['status']})")

        card_ids = json.loads(session["card_ids_json"])
        current_index = session["current_index"]
        card_id = card_ids[current_index]

        card_row = query_one(conn, "SELECT * FROM cards WHERE id = ?", (card_id,))
        if card_row is None:
            raise ValueError(f"Card {card_id} not found")

        # Grade the answer
        rating = _grade_answer(card_row, answer, answer_type, pronunciation_score, conn)

        # Update FSRS state
        next_interval = _apply_fsrs_rating(card_row, rating, conn)

        # Log the review
        _log_review(card_id, session_id, rating, answer, pronunciation_score, conn)

        # Advance session
        next_index = current_index + 1
        next_card = None
        if next_index < len(card_ids):
            next_card = _get_session_card(session_id, next_index, conn)

        execute(
            conn,
            "UPDATE sessions SET current_index = ?, cards_completed = ? WHERE id = ?",
            (next_index, session["cards_completed"] + 1, session_id),
        )

        # If last card, auto-end session
        if next_index >= len(card_ids):
            execute(
                conn,
                "UPDATE sessions SET status = 'completed', ended_at = ? WHERE id = ?",
                (_now_iso(), session_id),
            )
            logger.info("Session auto-completed (session_id=%s, cards=%d)", session_id, len(card_ids))

        conn.commit()

        result = {
            "card_id": card_id,
            "grade": rating,
            "next_interval": next_interval,
            "next_card": next_card,
        }

        # Include correct_option for MC cards
        if answer_type == "mc":
            result["correct_option"] = _get_correct_option(card_row)

        # Include pronunciation scores for audio cards
        if pronunciation_score:
            result["pronunciation"] = pronunciation_score

        logger.info("Answer submitted (card_id=%s, grade=%s, next_card=%s)",
                    card_id, rating, result.get("next_card", {}).get("id") if next_card else None)
        return result
    finally:
        conn.close()


def skip_card(session_id: str) -> dict:
    """Skip the current card — FSRS-neutral, just advance the queue.

    Per Decision #9: no scheduling impact. Card returns to queue unchanged.
    """
    logger.info("skip_card (session_id=%s)", session_id)

    conn = get_connection()
    try:
        session = query_one(conn, "SELECT * FROM sessions WHERE id = ?", (session_id,))
        if session is None:
            raise ValueError(f"Session {session_id} not found")
        if session["status"] != "in_progress":
            raise ValueError(f"Session {session_id} is not active")

        card_ids = json.loads(session["card_ids_json"])
        current_index = session["current_index"]
        card_id = card_ids[current_index]

        next_index = current_index + 1
        next_card = None
        if next_index < len(card_ids):
            next_card = _get_session_card(session_id, next_index, conn)

        execute(
            conn,
            "UPDATE sessions SET current_index = ?, cards_completed = ? WHERE id = ?",
            (next_index, session["cards_completed"] + 1, session_id),
        )

        if next_index >= len(card_ids):
            execute(
                conn,
                "UPDATE sessions SET status = 'completed', ended_at = ? WHERE id = ?",
                (_now_iso(), session_id),
            )

        conn.commit()
        logger.info("Card skipped (session_id=%s, card_id=%s, next_card=%s)",
                    session_id, card_id, next_card.get("id") if next_card else None)

        return {
            "card_id": card_id,
            "skipped": True,
            "next_card": next_card,
        }
    finally:
        conn.close()


def end_session(session_id: str) -> dict:
    """End a session manually. Returns summary stats."""
    logger.info("end_session (session_id=%s)", session_id)

    conn = get_connection()
    try:
        session = query_one(conn, "SELECT * FROM sessions WHERE id = ?", (session_id,))
        if session is None:
            raise ValueError(f"Session {session_id} not found")

        execute(
            conn,
            "UPDATE sessions SET status = 'completed', ended_at = ? WHERE id = ?",
            (_now_iso(), session_id),
        )
        conn.commit()

        # Get review stats from review_log
        stats = query_one(
            conn,
            """
            SELECT
                COUNT(*) as total,
                SUM(CASE WHEN rating = 'again' THEN 1 ELSE 0 END) as again,
                SUM(CASE WHEN rating = 'hard' THEN 1 ELSE 0 END) as hard,
                SUM(CASE WHEN rating = 'good' THEN 1 ELSE 0 END) as good,
                SUM(CASE WHEN rating = 'easy' THEN 1 ELSE 0 END) as easy
            FROM review_log WHERE session_id = ?
            """,
            (session_id,),
        )

        summary = {
            "session_id": session_id,
            "cards_completed": session["cards_completed"],
            "total_cards": session["total_cards"],
            "again": stats["again"] if stats else 0,
            "hard": stats["hard"] if stats else 0,
            "good": stats["good"] if stats else 0,
            "easy": stats["easy"] if stats else 0,
        }
        logger.info("Session ended (session_id=%s, completed=%d/%d)",
                     session_id, summary["cards_completed"], summary["total_cards"])
        return summary
    finally:
        conn.close()


def undo_last_rating(session_id: str) -> bool:
    """Undo the last rating in a session. Restores previous FSRS state.

    Per Decision #20. Uses session_undo table.
    """
    logger.info("undo_last_rating (session_id=%s)", session_id)

    conn = get_connection()
    try:
        undo_row = query_one(
            conn,
            "SELECT * FROM session_undo WHERE session_id = ? ORDER BY id DESC LIMIT 1",
            (session_id,),
        )
        if undo_row is None:
            logger.warning("No rating to undo (session_id=%s)", session_id)
            return False

        # Restore FSRS state
        execute(
            conn,
            "UPDATE cards SET fsrs_state_json = ?, fsrs_next_review = ? WHERE id = ?",
            (undo_row["previous_fsrs_state_json"], undo_row["previous_fsrs_next_review"],
             undo_row["card_id"]),
        )

        # Move session index back
        session = query_one(conn, "SELECT * FROM sessions WHERE id = ?", (session_id,))
        if session and session["current_index"] > 0:
            execute(
                conn,
                "UPDATE sessions SET current_index = ?, cards_completed = ? WHERE id = ?",
                (session["current_index"] - 1, max(0, session["cards_completed"] - 1), session_id),
            )

        # Delete the undo record
        execute(conn, "DELETE FROM session_undo WHERE id = ?", (undo_row["id"],))
        conn.commit()

        logger.info("Undo successful (session_id=%s, card_id=%s)", session_id, undo_row["card_id"])
        return True
    finally:
        conn.close()


# ─── Card info ────────────────────────────────────────────────────────────────


def get_card_explanation(card_id: int) -> str | None:
    """Get the grammar note for a card (per Decision #22 — 'spiega' feature)."""
    logger.info("get_card_explanation (card_id=%s)", card_id)

    conn = get_connection()
    try:
        row = query_one(conn, "SELECT grammar_note FROM cards WHERE id = ?", (card_id,))
        if row is None:
            raise ValueError(f"Card {card_id} not found")
        return row["grammar_note"]
    finally:
        conn.close()


def assess_pronunciation(audio_path: str, reference_text: str) -> dict:
    """Assess pronunciation via Azure Pronunciation Assessment.

    Returns: { overall_score, phonemes: [{ sound, score }] }
    """
    logger.info("assess_pronunciation (audio=%s, ref=%s...)", audio_path, reference_text[:30])

    # Azure Pronunciation Assessment — delegated to azure SDK
    # This will be implemented when we build the pronunciation feature
    # For now, return a placeholder structure
    import azure.cognitiveservices.speech as speechsdk

    # Full implementation requires audio streaming config — TODO
    raise NotImplementedError("Pronunciation assessment implementation pending")


# ─── Progress / Stats ─────────────────────────────────────────────────────────


def get_city_progress(user_id: int = 1) -> list[dict]:
    """Get progress for all cities. Returns list of city progress dicts."""
    logger.info("get_city_progress (user_id=%s)", user_id)

    conn = get_connection()
    try:
        rows = query_all(
            conn,
            """
            SELECT c.id, c.name, c.name_emoji, c.cefr_level, c.theme,
                   c.badge_name, c.sort_order, c.card_count, c.is_unlocked,
                   COALESCE(cp.badge_earned, 0) as badge_earned,
                   COALESCE(cp.gate_reached, 0) as gate_reached
            FROM cities c
            LEFT JOIN city_progress cp ON cp.city_id = c.id
            ORDER BY c.sort_order ASC
            """,
        )
        return [dict(r) for r in rows]
    finally:
        conn.close()


def get_cluster_strength(city_id: int) -> list[dict]:
    """Get cluster strength scores for a city. Used by Journey tab."""
    logger.info("get_cluster_strength (city_id=%s)", city_id)

    conn = get_connection()
    try:
        rows = query_all(
            conn,
            """
            SELECT cl.id, cl.name, cl.sort_order,
                   COUNT(c.id) as card_count,
                   AVG(CASE WHEN c.fsrs_state_json IS NOT NULL THEN 1.0 ELSE 0.0 END) as strength
            FROM clusters cl
            LEFT JOIN cards c ON c.cluster_id = cl.id
            WHERE cl.city_id = ?
            GROUP BY cl.id, cl.name, cl.sort_order
            ORDER BY cl.sort_order ASC
            """,
            (city_id,),
        )
        return [dict(r) for r in rows]
    finally:
        conn.close()


def get_stats_retention(days: int = 30) -> list[dict]:
    """Get retention curve data points for the Stats tab."""
    logger.info("get_stats_retention (days=%s)", days)

    conn = get_connection()
    try:
        rows = query_all(
            conn,
            """
            SELECT date(reviewed_at) as date,
                   COUNT(*) as reviews,
                   SUM(CASE WHEN rating IN ('good', 'easy') THEN 1 ELSE 0 END) as correct,
                   SUM(CASE WHEN rating = 'again' THEN 1 ELSE 0 END) as failed
            FROM review_log
            WHERE reviewed_at >= date('now', ?)
            GROUP BY date(reviewed_at)
            ORDER BY date ASC
            """,
            (f"-{days} days",),
        )
        return [dict(r) for r in rows]
    finally:
        conn.close()


def get_stats_history(days: int = 30) -> list[dict]:
    """Get daily review counts for the Stats tab."""
    return get_stats_retention(days)


def get_leeches() -> list[dict]:
    """Get the leech queue — cards with leech_flag set."""
    logger.info("get_leeches")

    conn = get_connection()
    try:
        rows = query_all(
            conn,
            """
            SELECT id, cluster_id, card_type, italian_text, english_text,
                   leech_fail_count, leech_flagged_at
            FROM cards WHERE leech_flag = 1
            ORDER BY leech_fail_count DESC
            """,
        )
        return [dict(r) for r in rows]
    finally:
        conn.close()


# ─── Settings ─────────────────────────────────────────────────────────────────


def get_settings(user_id: int = 1) -> dict:
    """Get server-side settings."""
    logger.info("get_settings (user_id=%s)", user_id)

    conn = get_connection()
    try:
        row = query_one(
            conn,
            "SELECT daily_review_cap, notification_time, session_timeout_minutes, "
            "audio_voice, audio_rate, api_key FROM user_settings WHERE id = ?",
            (user_id,),
        )
        if row is None:
            # Return defaults if no row exists yet
            return {
                "daily_card_cap": 20,
                "notification_time": "08:00",
                "session_timeout_minutes": 10,
                "audio_voice": "it-IT-LunaNeural",
                "audio_rate": 1.0,
            }
        return dict(row)
    finally:
        conn.close()


def update_settings(updates: dict, user_id: int = 1) -> dict:
    """Update server-side settings. Returns updated settings."""
    logger.info("update_settings (user_id=%s, keys=%s)", user_id, list(updates.keys()))

    allowed = {"daily_review_cap", "notification_time", "session_timeout_minutes",
               "audio_voice", "audio_rate"}

    filtered = {k: v for k, v in updates.items() if k in allowed}
    if not filtered:
        return get_settings(user_id)

    conn = get_connection()
    try:
        set_clauses = ", ".join(f"{k} = ?" for k in filtered)
        params = tuple(filtered.values()) + (_now_iso(), user_id)

        execute(
            conn,
            f"UPDATE user_settings SET {set_clauses}, updated_at = ? WHERE id = ?",
            params,
        )
        conn.commit()
        logger.info("Settings updated (keys=%s)", list(filtered.keys()))
        return get_settings(user_id)
    finally:
        conn.close()


# ─── Internal helpers ─────────────────────────────────────────────────────────


def _get_session_card(session_id: str, index: int, conn: sqlite3.Connection) -> dict | None:
    """Get the card at a given index in a session's queue."""
    session = query_one(conn, "SELECT card_ids_json FROM sessions WHERE id = ?", (session_id,))
    if session is None:
        return None

    card_ids = json.loads(session["card_ids_json"])
    if index < 0 or index >= len(card_ids):
        return None

    card_id = card_ids[index]
    row = query_one(conn, "SELECT * FROM cards WHERE id = ?", (card_id,))
    if row is None:
        return None

    return _card_to_dict(row)


def _grade_answer(card_row: sqlite3.Row, answer: Any, answer_type: str,
                  pronunciation_score: dict | None, conn: sqlite3.Connection) -> str:
    """Determine the FSRS rating for an answer.

    For text: compare to English translation (simple match for v1)
    For MC: check if selected option matches correct option
    For audio: use pronunciation overall score to determine rating
    """
    if answer_type == "mc":
        correct = _get_correct_option(card_row)
        if answer == correct:
            return "good"
        return "again"

    if answer_type == "audio" and pronunciation_score:
        score = pronunciation_score.get("overall_score", 0)
        if score >= 80:
            return "easy"
        if score >= 60:
            return "good"
        if score >= 40:
            return "hard"
        return "again"

    # Text answer — simple exact match for v1
    # TODO: LLM-based grading for production answers
    if answer_type == "text":
        correct = card_row["english_text"].strip().lower()
        given = str(answer).strip().lower()
        if given == correct:
            return "good"
        # Partial credit for close matches (v1: exact only)
        return "again"

    return "again"


def _get_correct_option(card_row: sqlite3.Row) -> int | None:
    """Get the correct option index for an MC card.

    For v1, MC cards store the correct option in the grammar_note field
    as a JSON object: {"correct_option": 2, "options": [...]}
    """
    if card_row["grammar_note"]:
        try:
            note = json.loads(card_row["grammar_note"])
            return note.get("correct_option")
        except (json.JSONDecodeError, TypeError):
            pass
    return None


def _apply_fsrs_rating(card_row: sqlite3.Row, rating: str, conn: sqlite3.Connection) -> str:
    """Apply an FSRS rating to a card. Updates fsrs_state_json and fsrs_next_review.

    Returns the next interval as a human-readable string.
    """
    rating_map = {
        "again": Rating.Again,
        "hard": Rating.Hard,
        "good": Rating.Good,
        "easy": Rating.Easy,
    }

    fsrs_rating = rating_map.get(rating, Rating.Good)

    # Load or create FSRS card state
    if card_row["fsrs_state_json"]:
        card = FSRSCard.from_dict(json.loads(card_row["fsrs_state_json"]))
    else:
        card = FSRSCard()

    scheduler = Scheduler()
    updated_card, log = scheduler.review(card, fsrs_rating)

    # Store previous state for undo
    execute(
        conn,
        "INSERT INTO session_undo (session_id, card_id, previous_fsrs_state_json, previous_fsrs_next_review) "
        "VALUES (?, ?, ?, ?)",
        ("", card_row["id"], card_row["fsrs_state_json"], card_row["fsrs_next_review"]),
    )

    # Update card with new FSRS state
    new_state_json = json.dumps(updated_card.to_dict())
    next_review = updated_card.due.isoformat() if updated_card.due else None

    execute(
        conn,
        "UPDATE cards SET fsrs_state_json = ?, fsrs_next_review = ?, updated_at = ? WHERE id = ?",
        (new_state_json, next_review, _now_iso(), card_row["id"]),
    )

    # Calculate human-readable interval
    if updated_card.due:
        now = datetime.now(timezone.utc)
        delta = updated_card.due - now
        total_seconds = delta.total_seconds()
        if total_seconds < 60:
            interval = f"{int(total_seconds)}s"
        elif total_seconds < 3600:
            interval = f"{int(total_seconds / 60)}m"
        elif total_seconds < 86400:
            interval = f"{int(total_seconds / 3600)}h"
        else:
            interval = f"{int(total_seconds / 86400)}d"
    else:
        interval = "0s"

    logger.debug("FSRS update (card_id=%s, rating=%s, next_review=%s, interval=%s)",
                card_row["id"], rating, next_review, interval)

    return interval


def _log_review(card_id: int, session_id: str, rating: str, answer: Any,
                pronunciation_score: dict | None, conn: sqlite3.Connection) -> None:
    """Log a review to review_log."""
    execute(
        conn,
        """
        INSERT INTO review_log (card_id, session_id, rating, answer_text, grade_correct,
                                pronunciation_score, phoneme_scores, reviewed_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            card_id,
            session_id,
            rating,
            str(answer) if answer is not None else None,
            1 if rating in ("good", "easy") else 0,
            pronunciation_score.get("overall_score") if pronunciation_score else None,
            json.dumps(pronunciation_score.get("phonemes")) if pronunciation_score else None,
            _now_iso(),
        ),
    )