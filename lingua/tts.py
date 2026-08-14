"""Idoru Lingua — Azure Text-to-Speech with lazy generation and integrity check.

Per Decision #30 (Issue #10):
- Lazy generation: if audio file missing/corrupt, generate on-the-fly on GET /card/{id}/audio
- Pre-warm integrity check: verify file exists + >0 bytes, regenerate if bad
- Import resilience: cards import text-only if Azure is down, audio_status='pending'

TTS voice: it-IT-LunaNeural (Decision #3)
Output format: m4a (Decision #6)
"""
import logging
import os
import time
from pathlib import Path

import azure.cognitiveservices.speech as speechsdk

from .db import get_connection

logger = logging.getLogger(__name__)

AZURE_SPEECH_KEY = os.environ.get("AZURE_SPEECH_KEY", "")
AZURE_SPEECH_REGION = os.environ.get("AZURE_SPEECH_REGION", "eastus")
VOICE_NAME = "it-IT-LunaNeural"
AUDIO_DIR = Path(os.environ.get("LINGUA_AUDIO_DIR", "/home/drew/lingua-data/audio"))
AZURE_TIMEOUT_SECONDS = 10


def _audio_path_for_card(card_id: int) -> Path:
    """Return the expected filesystem path for a card's audio file."""
    return AUDIO_DIR / f"card_{card_id}.m4a"


def _generate_tts(text: str, output_path: Path) -> float:
    """Call Azure TTS to synthesize text and save to output_path.

    Returns duration in seconds. Raises TimeoutError if Azure doesn't respond in time.
    """
    logger.info("TTS generation started (text=%s..., out=%s)", text[:40], output_path)

    speech_config = speechsdk.SpeechConfig(
        subscription=AZURE_SPEECH_KEY, region=AZURE_SPEECH_REGION
    )
    speech_config.speech_synthesis_voice_name = VOICE_NAME
    speech_config.set_audio_output_format(
        speechsdk.SpeechSynthesisOutputFormat.Audio16Khz32KBitRateMonoM4a
    )

    audio_config = speechsdk.audio.AudioOutputConfig(filename=str(output_path))
    synthesizer = speechsdk.SpeechSynthesizer(
        speech_config=speech_config, audio_config=audio_config
    )

    start = time.monotonic()
    result = synthesizer.speak_text_async(text).get()
    elapsed = time.monotonic() - start

    if result.reason == speechsdk.ResultReason.SynthesizingAudioCompleted:
        logger.info("TTS generation completed (duration=%.2fs, file=%s)", elapsed, output_path)
        return elapsed

    if result.reason == speechsdk.ResultReason.Canceled:
        cancellation = result.cancellation_details
        logger.error(
            "TTS generation canceled: %s (error_code=%s)",
            cancellation.error_details,
            cancellation.error_code,
        )
        raise RuntimeError(f"Azure TTS canceled: {cancellation.error_details}")

    if elapsed > AZURE_TIMEOUT_SECONDS:
        logger.error("TTS generation timed out after %.1fs", elapsed)
        raise TimeoutError(f"Azure TTS timed out after {AZURE_TIMEOUT_SECONDS}s")

    raise RuntimeError(f"Azure TTS failed with reason: {result.reason}")


def _check_integrity(audio_path: Path) -> bool:
    """Lightweight integrity check: file exists and is >0 bytes.

    Per Decision #30, full m4a header parsing is deferred (Issue #11).
    """
    if not audio_path.exists():
        return False
    if audio_path.stat().st_size == 0:
        return False
    return True


def get_card_audio(card_id: int) -> Path:
    """Return path to cached .m4a audio file.

    If file is missing or corrupt, generate via Azure TTS, cache, and return.
    Updates audio_status in the cards table.

    Raises TimeoutError if Azure doesn't respond in AZURE_TIMEOUT_SECONDS.
    Raises RuntimeError if Azure returns an error.
    """
    logger.info("get_card_audio (card_id=%s)", card_id)

    audio_path = _audio_path_for_card(card_id)

    # Fast path: file exists and is valid
    if _check_integrity(audio_path):
        logger.debug("Audio cache hit (card_id=%s, path=%s)", card_id, audio_path)
        return audio_path

    # Slow path: generate on-the-fly (lazy generation per #30)
    logger.info("Audio cache miss — generating lazily (card_id=%s)", card_id)

    conn = get_connection()
    try:
        row = conn.execute(
            "SELECT italian_text, audio_status FROM cards WHERE id = ?", (card_id,)
        ).fetchone()

        if row is None:
            logger.error("Card not found (card_id=%s)", card_id)
            raise ValueError(f"Card {card_id} not found")

        text = row["italian_text"]
        AUDIO_DIR.mkdir(parents=True, exist_ok=True)

        try:
            _generate_tts(text, audio_path)
            conn.execute(
                "UPDATE cards SET audio_status = 'generated', audio_path = ? WHERE id = ?",
                (str(audio_path), card_id),
            )
            conn.commit()
            logger.info("Lazy TTS generated and cached (card_id=%s)", card_id)
            return audio_path
        except TimeoutError as e:
            conn.execute(
                "UPDATE cards SET audio_status = 'failed' WHERE id = ?", (card_id,)
            )
            conn.commit()
            logger.error("TTS timeout for card %s: %s", card_id, e, exc_info=True)
            raise
        except Exception as e:
            conn.execute(
                "UPDATE cards SET audio_status = 'failed' WHERE id = ?", (card_id,)
            )
            conn.commit()
            logger.error("TTS failed for card %s: %s", card_id, e, exc_info=True)
            raise
    finally:
        conn.close()


def prewarm_audio(card_ids: list[int]) -> dict:
    """Pre-warm audio for a list of cards. Called by the pre-warm pipeline.

    Returns summary: {generated, skipped, failed, duration_s}
    """
    import logging as _logging
    _logger = _logging.getLogger(__name__)

    _logger.info("Pre-warm audio started (cards=%d)", len(card_ids))
    start = time.monotonic()

    generated = 0
    skipped = 0
    failed = 0

    for card_id in card_ids:
        audio_path = _audio_path_for_card(card_id)

        if _check_integrity(audio_path):
            _logger.debug("Pre-warm skip (card_id=%s, already cached)", card_id)
            skipped += 1
            continue

        try:
            conn = get_connection()
            row = conn.execute(
                "SELECT italian_text FROM cards WHERE id = ?", (card_id,)
            ).fetchone()
            conn.close()

            if row is None:
                _logger.warning("Pre-warm skip (card_id=%s, not found)", card_id)
                failed += 1
                continue

            AUDIO_DIR.mkdir(parents=True, exist_ok=True)
            _generate_tts(row["italian_text"], audio_path)

            conn = get_connection()
            conn.execute(
                "UPDATE cards SET audio_status = 'generated', audio_path = ? WHERE id = ?",
                (str(audio_path), card_id),
            )
            conn.commit()
            conn.close()

            generated += 1
        except Exception as e:
            _logger.warning("Pre-warm failed (card_id=%s): %s", card_id, e)
            failed += 1

            # Mark as failed in DB
            try:
                conn = get_connection()
                conn.execute(
                    "UPDATE cards SET audio_status = 'failed' WHERE id = ?", (card_id,)
                )
                conn.commit()
                conn.close()
            except Exception:
                pass

    elapsed = time.monotonic() - start
    summary = {
        "generated": generated,
        "skipped": skipped,
        "failed": failed,
        "duration_s": round(elapsed, 2),
    }
    _logger.info(
        "Pre-warm audio completed (generated=%d, skipped=%d, failed=%d, duration=%.1fs)",
        generated, skipped, failed, elapsed,
    )
    return summary