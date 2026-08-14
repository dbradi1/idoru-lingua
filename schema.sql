-- Idoru Lingua — Database Schema
-- SQLite with WAL mode + busy_timeout for concurrent read during pre-warm
--
-- Based on Fable architecture review §5, adapted with hybrid FSRS storage:
--   fsrs_state_json holds the full FSRS Card object as JSON (library-native)
--   fsrs_next_review is a real column for the only query we run against FSRS state
--   All other FSRS fields (stability, difficulty, reps, lapses, state) live inside the JSON blob
--
-- Maps to architecture decisions #1–#28.

-- ─── Pragmas ────────────────────────────────────────────────────────────────
-- Run these on every connection:
--   PRAGMA journal_mode = WAL;
--   PRAGMA busy_timeout = 5000;
-- ────────────────────────────────────────────────────────────────────────────

-- ─── 1. user_settings ──────────────────────────────────────────────────────
-- Single-user app; id is always 1. Structured for future multi-user.
CREATE TABLE IF NOT EXISTS user_settings (
    id INTEGER PRIMARY KEY DEFAULT 1,
    daily_review_cap INTEGER DEFAULT 20,       -- #25: max cards per morning session
    notification_time TEXT DEFAULT '07:00',    -- #25: when morning cron fires
    api_key TEXT,                              -- #28: auth token for REST API
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

-- ─── 2. cities ──────────────────────────────────────────────────────────────
-- 8 rows, from #13. Gamification map: each city = a CEFR level + theme.
CREATE TABLE IF NOT EXISTS cities (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,           -- "Roma"
    name_emoji TEXT,              -- "🏛️"
    cefr_level TEXT NOT NULL,     -- "A1.1"
    theme TEXT NOT NULL,          -- "Arrival"
    badge_name TEXT,              -- "Found your feet in the Eternal City"
    sort_order INTEGER NOT NULL,  -- 1–8
    card_count INTEGER,           -- denormalized for quick display
    cluster_count INTEGER,
    is_unlocked INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now'))
);

-- ─── 3. clusters ────────────────────────────────────────────────────────────
-- 46 rows, from #13. Skill clusters within each city.
CREATE TABLE IF NOT EXISTS clusters (
    id INTEGER PRIMARY KEY,
    city_id INTEGER NOT NULL REFERENCES cities(id),
    name TEXT NOT NULL,           -- "Café Ordering"
    sort_order INTEGER NOT NULL,
    created_at TEXT DEFAULT (datetime('now'))
);

-- ─── 4. cards ───────────────────────────────────────────────────────────────
-- ~840 rows at full build, from #11/#13.
-- Hybrid FSRS: JSON blob for full state + real column for due-date queries.
CREATE TABLE IF NOT EXISTS cards (
    id INTEGER PRIMARY KEY,
    cluster_id INTEGER NOT NULL REFERENCES clusters(id),
    card_type TEXT NOT NULL,      -- 'vocab'|'phrase'|'grammar'|'pronunciation'|'production'
    italian_text TEXT NOT NULL,
    english_text TEXT NOT NULL,
    grammar_note TEXT,            -- for spiega (#22)
    audio_path TEXT,              -- relative path to cached TTS file
    reference_text TEXT,          -- for pronunciation cards (may differ from italian_text)
    -- FSRS state (hybrid approach)
    fsrs_state_json TEXT,         -- full FSRS Card object serialized as JSON
    fsrs_next_review TEXT,        -- ISO timestamp; only queryable FSRS field
    -- Leech tracking (#19)
    leech_flag INTEGER DEFAULT 0,
    leech_fail_count INTEGER DEFAULT 0,
    leech_flagged_at TEXT,
    -- Import tracking (#17)
    import_source TEXT,           -- 'anki_travel_deck'|'frequency_500'|'manual'
    import_validated INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

-- ─── 5. review_log ──────────────────────────────────────────────────────────
-- Every rating, for stats, retention curves (#27), session summaries, undo support.
CREATE TABLE IF NOT EXISTS review_log (
    id INTEGER PRIMARY KEY,
    card_id INTEGER NOT NULL REFERENCES cards(id),
    session_id INTEGER REFERENCES sessions(id),
    rating TEXT NOT NULL,         -- 'again'|'hard'|'good'|'easy'
    answer_text TEXT,             -- what Drew typed/said
    grade_correct INTEGER,        -- LLM/MC/phoneme result
    grade_feedback TEXT,          -- LLM feedback or correction
    pronunciation_score REAL,     -- for pronunciation cards only
    phoneme_scores TEXT,          -- JSON array of {sound, score}
    reviewed_at TEXT DEFAULT (datetime('now'))
);

-- ─── 6. sessions ────────────────────────────────────────────────────────────
-- Session state, server-side per #28. Replaces pending_card_id from #4.
CREATE TABLE IF NOT EXISTS sessions (
    id INTEGER PRIMARY KEY,
    user_id INTEGER DEFAULT 1,
    card_ids TEXT NOT NULL,       -- JSON array of card IDs in queue order
    current_index INTEGER DEFAULT 0,
    status TEXT DEFAULT 'pending_start',  -- 'pending_start'|'active'|'completed'|'expired'|'cancelled'
    source TEXT,                  -- 'morning_cron'|'on_demand'|'leech_review'|'free_practice'|'pronunciation_drill'
    total_cards INTEGER,
    cards_good INTEGER DEFAULT 0,
    cards_hard INTEGER DEFAULT 0,
    cards_again INTEGER DEFAULT 0,
    started_at TEXT,
    ended_at TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

-- ─── 7. session_undo ────────────────────────────────────────────────────────
-- Undo support per #20. Stores previous FSRS state to revert last rating.
CREATE TABLE IF NOT EXISTS session_undo (
    id INTEGER PRIMARY KEY,
    session_id INTEGER NOT NULL REFERENCES sessions(id),
    card_id INTEGER NOT NULL,
    previous_fsrs_state_json TEXT,  -- full FSRS Card object before the rating
    previous_fsrs_next_review TEXT, -- due date before the rating
    created_at TEXT DEFAULT (datetime('now'))
);

-- ─── 8. prewarm_log ─────────────────────────────────────────────────────────
-- Pre-warm pipeline state per #25.
CREATE TABLE IF NOT EXISTS prewarm_log (
    id INTEGER PRIMARY KEY,
    session_id INTEGER REFERENCES sessions(id),
    cards_due INTEGER,
    cards_validated INTEGER,
    cards_skipped INTEGER,
    audio_generated INTEGER,
    status TEXT,                  -- 'success'|'partial'|'failed'|'timeout'
    error_detail TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

-- ─── 9. city_progress ───────────────────────────────────────────────────────
-- Gate/badge tracking per city.
CREATE TABLE IF NOT EXISTS city_progress (
    id INTEGER PRIMARY KEY,
    city_id INTEGER NOT NULL REFERENCES cities(id),
    badge_earned INTEGER DEFAULT 0,
    badge_earned_at TEXT,
    gate_reached INTEGER DEFAULT 0,
    gate_reached_at TEXT
);

-- ─── Indexes ────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_cards_next_review ON cards(fsrs_next_review);
CREATE INDEX IF NOT EXISTS idx_cards_cluster ON cards(cluster_id);
CREATE INDEX IF NOT EXISTS idx_review_log_card ON review_log(card_id);
CREATE INDEX IF NOT EXISTS idx_review_log_session ON review_log(session_id);
CREATE INDEX IF NOT EXISTS idx_clusters_city ON clusters(city_id);