# Proposal: API Endpoint Refinement (Issue #9)

**Status:** APPROVED — all 5 open questions resolved  
**Date:** 2026-08-14  
**Supersedes portions of:** Decision #28 (API Layer: FastAPI + Thin REST)  
**GitHub Issue:** [#9](https://github.com/dbradi1/idoru-lingua/issues/9)

**Drew's decisions on open questions:**
1. Session model: **Option A (thin mapper)** ✅
2. Skip behavior: **Neutral (no FSRS penalty)** ✅
3. Health endpoint auth: **No auth** ✅
4. Audio formats: **m4a/wav/mp3 (no ogg)** ✅
5. Settings split: **Approved as proposed** ✅

---

## Summary

Six targeted refinements to the API spec from Decision #28. No architectural reversal — FastAPI, port 5051, Tailscale binding, Bearer auth, and `/api/v1/` versioning all remain. These are additive changes that split an overloaded endpoint, fill gaps in the endpoint roster, and add machine-readable error handling.

---

## 1. Split `submit` into typed endpoints

### What changed

**Before (#28):**
```
POST /api/v1/session/{id}/submit — submit answer for current card, returns grade + next card
```

**After:**
```
POST /api/v1/session/{id}/submit/text   — typed answers (Italian text input)
POST /api/v1/session/{id}/submit/mc     — multiple choice (selected option index)
POST /api/v1/session/{id}/submit/audio  — spoken answers (multipart upload)
```

### Why

- **Request validation differs radically by answer type.** Text needs string + length bounds. MC needs an integer option index. Audio needs multipart with file size limits + format validation. One endpoint with a discriminated union payload is harder to validate and harder to document.
- **OpenAPI codegen benefits.** When we generate Swift models from the OpenAPI spec, three typed endpoints produce three clean request structs. One overloaded endpoint produces a messy enum or `Any` payload.
- **Error messages get specific.** "Audio file exceeds 10 MB limit" vs. "Answer text exceeds 500 character limit" — separate endpoints make this natural.

### Request/response shapes

**POST `/api/v1/session/{id}/submit/text`**
```json
// Request
{ "answer": "io mangio la mela" }

// Response 200
{
  "card_id": 42,
  "grade": "again",
  "next_interval": "0s",
  "next_card": { "id": 43, "front": "lei ___ la mela", "type": "text", ... } | null
}
```

**POST `/api/v1/session/{id}/submit/mc`**
```json
// Request
{ "selected_option": 2 }

// Response 200
{
  "card_id": 42,
  "grade": "good",
  "next_interval": "10m",
  "correct_option": 2,        // included so app can highlight correct answer on wrong picks
  "next_card": { "id": 44, "front": "...", "type": "mc", "options": [...], ... } | null
}
```

**POST `/api/v1/session/{id}/submit/audio`**
```
Content-Type: multipart/form-data

Fields:
  audio    — file (m4a, wav, or mp3; max 10 MB)
  duration — float (seconds, optional, for UI display)
```
```json
// Response 200
{
  "card_id": 42,
  "grade": "good",
  "next_interval": "10m",
  "pronunciation": {                    // included when audio is scored
    "overall_score": 78,
    "phonemes": [
      { "sound": "gli", "score": 45 },
      { "sound": "r", "score": 92 }
    ]
  } | null,
  "next_card": { ... } | null
}
```

### What happens to the old endpoint?

`POST /api/v1/session/{id}/submit` is **removed from v1 spec** (no code exists yet, so no deprecation needed). If we ever ship v1 with code and then change it, we'd deprecation-redirect. But since #28 is pre-implementation spec, we just replace it.

---

## 2. New endpoints

### `GET /api/v1/session/active`

Returns the current active session (if any) + current card. Designed for app resume after background/force-close.

```json
// Response 200 (session active)
{
  "session": {
    "id": "sess_abc123",
    "started_at": "2026-08-14T09:15:00-04:00",
    "cards_total": 12,
    "cards_completed": 5,
    "status": "in_progress"
  },
  "current_card": {
    "id": 43,
    "front": "lei ___ la mela",
    "type": "text",
    "city_id": 3,
    "cluster_id": 7
  }
}

// Response 200 (no active session)
{ "session": null, "current_card": null }
```

**Note:** Returns 200 with `null` body, not 404. "No active session" is a normal state, not an error.

### `POST /api/v1/session/{id}/skip`

Explicit skip — don't wait for the 10-minute timeout. Card goes back to the review queue (re-presented later in session or next session, per FSRS).

```json
// Request (empty body)
{}

// Response 200
{
  "card_id": 42,
  "skipped": true,
  "next_card": { "id": 43, "front": "...", ... } | null
}
```

**Engine behavior:** Skip does NOT grade the card. It's a non-event for FSRS — the card's scheduling is unaffected. It simply advances the session queue. This is distinct from "again" (which resets the interval).

### `GET /api/v1/health`

Lightweight liveness check for the app's offline detection.

```json
// Response 200
{
  "status": "ok",
  "version": "0.1.0",
  "azure_status": "reachable"    // "reachable" | "degraded" | "unreachable"
}
```

**Design notes:**
- No auth required (public endpoint) — the app needs to check connectivity before it has a valid auth context
- `azure_status` is a cached check (updated every 60s server-side) — not a live probe on every health request (would add latency + Azure quota burn)
- `version` lets the app detect incompatible server versions
- Response time target: <50ms

---

## 3. Session Model

### The gap

Decision #24 (engine) defines functions in terms of `card_id`:
- `get_due_cards()`
- `grade_card(card_id, rating)`
- `get_card_explanation(card_id)`

Decision #28 (REST) defines endpoints in terms of `session_id`:
- `POST /api/v1/session/{id}/submit/...`

Something has to bridge "session X is on card Y" → "grade card Y" → "advance to card Z."

### Options

**Option A: Thin mapper (stateless)**

Session state lives entirely in `lingua.db`. The API layer is a thin translator:

```python
# Pseudocode
@router.post("/session/{session_id}/submit/text")
async def submit_text(session_id: str, body: TextSubmit):
    session = db.get_session(session_id)          # fetch current card_id
    result = engine.grade_card(session.current_card_id, body.answer)
    next_card = db.advance_session(session_id)    # pop next from queue
    db.update_session(session_id, next_card.id)
    return {"grade": result, "next_card": next_card}
```

- **Pros:** No new classes, minimal code, all state in SQLite (durable across restarts)
- **Cons:** Every request hits DB twice (get session, update session) — fine for single-user but not elegant
- **Session table in lingua.db:** `sessions(id, created_at, status, card_queue_json, current_index, cards_completed)`

**Option B: Stateful session object (in-memory)**

Session loaded into a Python object on `start`, kept in a dict, persisted to DB on changes:

```python
class LinguaSession:
    id: str
    card_ids: list[int]
    current_index: int
    status: str  # "in_progress" | "completed" | "abandoned"
    
    def current_card(self) -> int: return self.card_ids[self.current_index]
    def advance(self) -> int | None: ...
    def skip(self) -> int | None: ...
```

- **Pros:** Cleaner API layer code, fewer DB hits per request, session logic is testable in isolation
- **Cons:** State in memory + DB = sync burden. If API restarts mid-session, must reload from DB (which means DB needs the full state anyway). In-memory state doesn't survive systemd restart.

**Recommendation: Option A (thin mapper)**

Rationale:
- Single-user app — DB hit overhead is negligible (local SQLite, <1ms per query)
- Durable by default — if the API restarts mid-session, `GET /session/active` reads from DB and resume works
- No sync bugs — there's no second source of truth to get out of sync
- The session table is simple and the mapper functions are ~5 lines each

The `sessions` table in `lingua.db`:

```sql
CREATE TABLE sessions (
    id TEXT PRIMARY KEY,              -- UUID or sess_<random>
    created_at TEXT NOT NULL,         -- ISO 8601
    status TEXT NOT NULL,             -- 'in_progress' | 'completed' | 'abandoned'
    card_ids_json TEXT NOT NULL,      -- JSON array of card IDs in queue order
    current_index INTEGER NOT NULL DEFAULT 0,
    cards_completed INTEGER NOT NULL DEFAULT 0,
    ended_at TEXT                     -- nullable, set when status changes
);
```

**Session lifecycle:**
1. `POST /session/start` → create row with status `in_progress`, full card queue
2. `submit/*` or `skip` → increment `current_index`, bump `cards_completed`
3. `POST /session/{id}/end` → set status `completed`, set `ended_at`
4. `GET /session/active` → query `WHERE status = 'in_progress' ORDER BY created_at DESC LIMIT 1`
5. Abandoned sessions (no activity for 1 hour) → auto-mark `abandoned` by a cleanup tick

---

## 4. Machine-readable error codes

### What changed

**Before (#28):**
```json
{ "error": "Card not found" }
```

**After:**
```json
{ "error": "Card not found", "code": "CARD_NOT_FOUND" }
```

### Error code catalog

| Code | HTTP | Meaning |
|------|------|---------|
| `UNAUTHORIZED` | 401 | Missing or invalid API key |
| `SESSION_NOT_FOUND` | 404 | Session ID doesn't exist |
| `SESSION_NOT_ACTIVE` | 409 | Session exists but isn't in_progress |
| `CARD_NOT_FOUND` | 404 | Card ID doesn't exist |
| `VALIDATION_ERROR` | 422 | Malformed request body |
| `ANSWER_TOO_LONG` | 422 | Text answer exceeds 500 chars |
| `AUDIO_TOO_LARGE` | 413 | Audio file exceeds 10 MB |
| `UNSUPPORTED_AUDIO_FORMAT` | 415 | Audio format not in accepted list |
| `AZURE_TIMEOUT` | 504 | Azure Speech didn't respond in 30s |
| `AZURE_ERROR` | 502 | Azure returned an error |
| `DB_ERROR` | 500 | SQLite operation failed |
| `INTERNAL_ERROR` | 500 | Unhandled exception |
| `RATE_LIMITED` | 429 | (reserved — not active in v1) |

**Format:** Every error response is `{ "error": "<human message>", "code": "<CODE>" }`. The app can switch on `code`, display `error` as fallback text.

---

## 5. Accepted audio formats

### Pronunciation assessment (`POST /api/v1/pronunciation/assess`)

| Format | Container | Notes |
|--------|-----------|-------|
| m4a | MP4/M4A | **Preferred** — native iOS recording format via AVAudioEngine |
| wav | WAV | Uncompressed, supported by Azure |
| mp3 | MP3 | Supported but not recommended (lossy compression degrades phoneme scoring) |

**Limits:**
- Max file size: 10 MB
- Max duration: 60 seconds
- Min duration: 0.5 seconds (filter accidental taps)
- Sample rate: 16 kHz+ recommended (Azure downsamples internally, but higher = better)

**Rejected formats:** ogg, flac, aiff — not natively supported by Azure Pronunciation Assessment without server-side transcoding. If we need them later, we add ffmpeg transcoding as a server-side step.

### Spoken answer submission (`POST /api/v1/session/{id}/submit/audio`)

Same format list and limits as pronunciation assessment. The audio is scored for pronunciation AND graded for card progression in one round-trip.

---

## 6. Server-side vs app-local settings

### Server-side (authoritative — read/written via API)

| Setting | Type | Default | Why server-side |
|---------|------|---------|-----------------|
| daily_card_cap | int | 20 | FSRS scheduling depends on it — engine needs the value |
| notification_time | str | "08:00" | Server triggers the morning push |
| session_timeout_minutes | int | 10 | Server enforces the auto-end |
| audio_voice | str | "it-IT-LunaNeural" | Server generates TTS |
| audio_rate | float | 1.0 | Server generates TTS |

**Endpoints (unchanged from #28):**
- `GET /api/v1/settings` → returns all server-side settings
- `PATCH /api/v1/settings` → update one or more

### App-local (stored in iOS UserDefaults/Keychain — never sent to server)

| Setting | Type | Default | Why app-local |
|---------|------|---------|---------------|
| api_key | str | — | Security — Keychain only |
| haptic_feedback | bool | true | Pure UI preference |
| card_font_size | str | "medium" | Pure UI preference |
| last_session_id | str? | nil | Resume hint (server is still source of truth via /session/active) |
| cached_progress | json? | nil | Offline display fallback |
| pronunciation_auto_play | bool | true | UI behavior |

**No endpoint needed** for app-local settings — they never touch the API.

---

## Migration plan

Next steps:

1. **Update README.md** — append this as "Decision #28 Amendment — Issue #9" section, mark the original #28 endpoints table as "see amendment" where changed
2. **Update Issue #9** — comment with decision summary, close issue
3. **Update `schema.sql`** — add `sessions` table DDL
4. **No code changes** — still pre-implementation; this is spec only

---

## Open questions for Drew

1. **Session model:** Option A (thin mapper, all state in SQLite) is my recommendation. Agree, or do you want the stateful object approach?
2. **Skip behavior:** Should skip be FSRS-neutral (no scheduling impact) or should it count as a "weak" review (slight interval reduction)? I vote neutral — skip = "I don't want to deal with this now," not "I got it wrong."
3. **Health endpoint auth:** I proposed no auth (so app can check connectivity pre-login). OK with that, or should it require the key?
4. **Audio format list:** m4a/wav/mp3 sufficient, or do you want ogg support (would require server-side ffmpeg)?
5. **Settings split:** Anything you'd move from server-side to app-local or vice versa?