<p align="center">
  <img src="assets/logo.png" width="200" height="200" alt="Idoru Lingua"/>
</p>

# Idoru Lingua — Italian Journey

A language learning system built on spaced repetition, designed around a journey through Italian cities. Telegram-native interaction, Mission Control dashboard, grounded in real memory science.

## Design Status: In Progress
**Last updated:** 2026-07-20

---

## Core Concept

**Italian Journey** — progression maps to traveling through Italian cities (Roma → Firenze → Venezia → etc.), each tied to real language milestones. Memory Strength (0-100%) reflects actual retention, not fake XP.

### What This Is
- Spaced repetition engine (FSRS) tracking real memory state
- Skill clusters organized by city (ordering food in Roma, navigating transit in Firenze)
- Telegram-native reviews — morning push + on-demand quizzes + conversational practice
- Mission Control dashboard with visual map, Memory Strength gauges, weak spots
- Badges tied to real abilities ("Ordered coffee entirely in Italian"), not grinding

### What This Is NOT
- No leaderboards
- No meaningless XP
- No streak anxiety
- No easy-mode grinding
- No engagement-bait gamification

---

## Architectural Decisions

### 1. Spaced Repetition Algorithm: FSRS ✅
**Decision:** Use FSRS (Free Spaced Repetition Scheduler) via Python `fsrs` library.

**Rationale:**
- Handles irregular review schedules (Telegram-based, not rigid daily sessions) better than SM-2
- No "ease hell" problem that plagues SM-2
- Targets specific retention rate (90%) and optimizes intervals to hit it
- Python library (`fsrs` on PyPI) makes implementation as easy as SM-2
- Models: Stability, Retrievability, Difficulty, Stability-after-review

**Alternatives considered:**
- SM-2 (Anki's algorithm) — simpler but ease hell, assumes regular scheduling
- Custom — more work, no clear benefit over FSRS

### 2. Data Model: Hybrid (Cards → Skill Clusters → Cities) ✅
**Decision:** Individual cards roll up into skill clusters, skill clusters roll up into city milestones.

**Structure:**
- **Card** — single vocab item, grammar rule, or phrase with FSRS state
- **Skill Cluster** — capability group (e.g., "ordering food," "asking directions"); Memory Strength = weighted average of card retrievability
- **City** — collection of skill clusters; city Memory Strength = weighted average of clusters

**Influences:**
- Duolingo's model (exercises → skills → units) validates this approach
- Key difference: we use Memory Strength percentage instead of crown levels (0-5) — more honest, less engagement-bait

**What we borrow from Duolingo:**
- Skill clusters as primary unit (not individual cards)
- Decay over time (FSRS handles per-card, we aggregate up)
- Adaptive targeting (weakest clusters prioritized in review queue)

**What we skip from Duolingo:**
- Crowns system (engagement bait)
- Real-time difficulty manipulation (FSRS handles this naturally)
- ML-based personalization engine (overkill for v1)

### 3. Grading: Mixed (LLM + Multiple Choice + Azure Phoneme Scoring) ✅
**Decision:** LLM judging for free-form answers, multiple choice for quick vocab, Azure Pronunciation Assessment for voice.

**Details:**
- Free-form text/voice answers → LLM grades correctness + provides feedback (Gemini 2.0 Flash for cost efficiency)
- Multiple choice for quick recognition drills (keeps API cost down)
- Voice answers transcribed via local Whisper for free-form text extraction
- **Pronunciation scoring:** Azure Pronunciation Assessment (it-IT) — phoneme-level accuracy scores, not just transcription matching. Returns per-sound scores: "your /gli/ was 45% accurate." Genuinely useful feedback, not just a gatekeeper.
- **TTS voice for Italian reference audio:** Azure Speech `it-IT-LunaNeural` — selected by Drew after sampling 42 Azure Italian voices via Verbatik gallery. Italian-native neural voice, not an English model attempting Italian.
- **Bundled provider:** Azure Speech handles both TTS (reference audio generation) and STT (pronunciation assessment) — one SDK, one auth, one provider for all voice features.

### 4. Telegram Flow: Dedicated Group Chat + Sequential Review ✅
**Decision:** All Lingua interaction happens in a dedicated Telegram group chat. One card at a time, interactive sequential flow.

**Dedicated group chat:**
- Separate Telegram group created specifically for Lingua
- Eliminates mixed-conversation ambiguity — every message in this chat is Lingua-related
- If Italian is requested in the main chat → redirect to Lingua group

**Session flow:**
1. Morning push (cron): "☕ N cards due — type *pronto* to start"
2. `pronto` → send card 1 (with audio)
3. Drew answers → grade, send feedback, immediately send card 2
4. Repeat until queue empty or Drew says `basta`
5. Session summary: "15 cards reviewed: 12 good, 2 hard, 1 again. Roma: 72% (+3%)"

**Trigger words (Italian):**
- `pronto` — start a review session
- `basta` — stop mid-session
- `quiz me` — on-demand session (same flow, any time)

**State management:**
- One `pending_card_id` + timestamp stored in session state
- 10-minute timeout per card → marked "skipped" (not failed), goes back in queue
- Only one card pending at a time — no batch ambiguity

### 5. Storage: SQLite (separate `lingua.db`) ✅
**Decision:** Dedicated SQLite database file. Does not touch existing SQLite data.

**Exposure:** Thin API endpoint in Mission Control, same pattern as diary/health endpoints.

### 6. Delivery: Telegram + Mission Control (no separate app) ✅
**Decision:** Telegram is the daily driver for learning interaction. Mission Control is the dashboard for visualization.

**Telegram handles:**
- Daily review push ("☕ Italian coffee break — 8 cards due")
- Inline quiz interactions (answer in chat, graded immediately)
- Conversational practice ("try ordering coffee" → you type → I correct)
- Phrase of the day, pronunciation nudges
- On-demand "quiz me"
- Generated postcards on city arrival / level-up

**Mission Control handles:**
- Visual map of Italy with current city
- Memory Strength gauges per skill cluster
- Review history, retention curves
- Weak spot heatmap
- Badge/landmark gallery

**Standalone UI:** Not needed for v1. If we want dedicated study sessions later, build as Mission Control page (v2).

### 7. Scheduling: Hybrid (Morning Push + On-Demand) ✅
**Decision:** Morning "Italian coffee break" push with due cards, plus on-demand quizzes via Telegram.

**Details:**
- Morning push: due cards delivered as a Telegram batch
- On-demand: "quiz me" triggers a session from the review queue
- Nudge when overdue items pile up
- Review queue = FSRS due cards sorted by cluster weakness (weakest first)

### 8. Progression: Three-Tier Gate Model ✅
**Decision:** Three thresholds — a floor, a gate, and a badge. Prevents skipping skill areas while allowing forward progress with gaps.

**Thresholds:**
- **30% per cluster (floor):** Minimum engagement with every skill area. If any cluster is below 30%, the next city stays locked. Not mastery — just "you've tried this enough to have some retention."
- **60% city average (gate):** Solid enough foundation to move forward without drowning. **Unlocks next city.**
- **85% all clusters (badge):** Genuine mastery — you can actually use this stuff. **Unlocks mastered badge for the city.**

**How weak clusters get fixed:**
- FSRS keeps scheduling weak-cluster cards in the review queue
- Review queue prioritizes weakest clusters first — the system naturally pushes you to fix gaps
- No guilt-trip messaging — just "2 clusters below the bar — they're in your review queue"
- Weak spots visible on the Mission Control map but don't block progress (as long as they're above 30%)

---

### 15. Voice Provider: Azure Speech (TTS + Pronunciation Assessment) ✅
**Decision:** Bundle both voice features under Azure Speech — one provider, one SDK, one auth.

**TTS (reference audio generation):**
- Voice: `it-IT-LunaNeural` — Italian-native neural voice, selected by Drew
- Pricing: $16/million characters (prebuilt neural). Free tier: 500K chars/month (~83K words)
- Roma card set (~60 cards × ~15 chars) = ~900 characters. Regenerable 500+ times on free tier alone.
- Audio cached as `.ogg` files — generate once, reuse forever

**Pronunciation Assessment (STT scoring):**
- Italian (it-IT) — phoneme-level accuracy scores
- $0.66/hour for short audio (<30s), prorated per second. ~$0.0005 per word check.
- Free tier: 5 hours/month included
- 30-second max per request — perfect for single word/phrase cards

**What this replaces:**
- TTS: OpenAI nova → Azure Luna (Italian-native, better Italian pronunciation)
- Pronunciation: Whisper transcription matching → Azure phoneme scoring (actual per-sound accuracy, not "did we hear the right word")
- Whisper (local) still used for free-form answer transcription

**Auth:** Single Azure Speech resource. Env vars: `AZURE_SPEECH_KEY` + `AZURE_SPEECH_REGION`

### 16. LLM Grading: DeepSeek V4 Pro via Dedicated Lingua Agent ✅
**Decision:** Dedicated OpenClaw sub-agent (`lingua`) with model override `ollama/deepseek-v4-pro` for answer grading.

**Why a sub-agent, not inline calls:**
- v1 grading is a function (API call), but v1.1 conversation cards need multi-turn dialogue with persona — a sub-agent handles both
- Clean separation from main session — Lingua doesn't compete with Idoru's other work
- Own context window — no polluting main session history with Italian grading
- Model can be swapped independently (DeepSeek V4 Pro now, can change later without touching other agents)

**Architecture:**
- `lingua_engine.py` (headless library) handles FSRS, card state, Azure TTS/pronunciation, DB operations
- Lingua sub-agent calls the engine library + handles Telegram flow in the Lingua group chat
- Grading model: `ollama/deepseek-v4-pro` — cheaper and faster than GLM 5.2 for simple correctness checking
- Main session (Idoru) redirects Italian requests to the Lingua group chat

---

### 24. Engine Architecture: Headless Python Library ✅
**Decision:** Build the core engine as a headless Python library (`lingua_engine.py`) with a clean API. Both the Lingua sub-agent and Mission Control dashboard call the same library — no duplicated logic.

**Library: `lingua_engine.py`**

Core API:
```python
# Session management
get_due_cards(user_id, limit=20) → list[Card]
submit_answer(card_id, answer, mode) → Grade
undo_last_rating(user_id) → bool

# Progression
get_city_progress(user_id) → dict
get_cluster_strength(city_id) → dict
check_progression_gate(user_id, city_id) → dict  # {can_advance: bool, blockers: list}

# Card management
get_card_explanation(card_id) → str  # grammar note
flag_leech(card_id) → bool  # move to re-learning queue
get_relearning_queue(user_id) → list[Card]

# Validation
validate_import(deck_path) → ImportReport  # one-time on deck load
prewarm_session(user_id) → SessionBatch  # daily, before morning push

# TTS (Azure Luna)
generate_audio(text) → path  # cached .ogg file
get_cached_audio(card_id) → path | None

# Pronunciation (Azure Assessment)
assess_pronunciation(audio_path, reference_text) → PronunciationScore  # phoneme-level
```

**Consumers:**
- **Lingua sub-agent** (Telegram): calls `get_due_cards()`, `submit_answer()`, `assess_pronunciation()`, etc. Handles the conversational flow.
- **Mission Control** (Flask blueprint): calls `get_city_progress()`, `get_cluster_strength()`, renders dashboard.
- **Morning cron**: calls `prewarm_session()`, then sends the push message.
- **Import script**: calls `validate_import()` when loading Anki decks.

**Tech stack:**
- Python 3.12+ (matches existing Idoru infra)
- `fsrs` library (PyPI) for spaced repetition
- `azure-cognitiveservices-speech` for TTS + pronunciation assessment
- SQLite with WAL mode (`lingua.db`)
- Flask blueprint in Mission Control for dashboard (reuses existing auth, styling, base templates)
- Whisper (local, existing) for free-form answer transcription

## Open To-Do Items (tracked in GitHub Issues)
- **#2** Azure Speech resource creation (blocked on Drew's Azure login)
- **#3** Lingua sub-agent setup in OpenClaw config
- **#4** Install Xcode on MacBook Pro for native iOS development
- **Drew to-do:** Create Telegram Lingua group chat (for notification channel)
- **Drew to-do:** Review Lingua SOUL.md draft (emailed)
- **Drew to-do:** Install Xcode (Issue #4)
- **Remaining:** API layer design, Anki import process, Roma/Firenze content creation, iOS app build
### 13. City Map: 8 Cities (CEFR A1 → B2) ✅
**Decision:** 8 cities, 46 skill clusters, ~840 cards. Progressive volume. Geographic spiral through Italy.

**Route:**
1. 🏛️ **Roma** (A1.1 — Arrival) — greetings, numbers/time, café ordering, directions. ~60 cards, 4 clusters. Badge: "Found your feet in the Eternal City"
2. 🌸 **Firenze** (A1.2 — Settling In) — restaurant/food vocab, shopping, present tense regular verbs, adjectives. ~80 cards, 5 clusters. Badge: "Dined like a Florentine"
3. 🚂 **Bologna** (A2.1 — Getting Around) — train/travel, passato prossimo, daily life, making plans. ~90 cards, 5 clusters. Badge: "Navigated the station like a local"
4. 🌊 **Venezia** (A2.2 — Conversations Begin) — opinions, weather, family, imperfetto, requests. ~100 cards, 6 clusters. Badge: "Made small talk on a gondola"
5. 🍷 **Verona** (B1.1 — Stories & Romance) — passato remoto, emotions, conditional, storytelling. ~110 cards, 6 clusters. Badge: "Told a story worth hearing"
6. 🏙️ **Napoli** (B1.2 — Street Italian) — formal/informal register, imperative, dialect awareness, idioms, arguing. ~120 cards, 6 clusters. Badge: "Held your own in a Naples piazza"
7. 🏖️ **Amalfi** (B2.1 — Fluency Building) — subjunctive, hypotheticals, reading comprehension, abstract topics. ~130 cards, 7 clusters. Badge: "Discussed art on a cliffside"
8. 🏔️ **Torino** (B2.2 — Mastery) — advanced grammar, formal writing, professional Italian, cultural fluency. ~150 cards, 7 clusters. Badge: "Passed for a Torinese"

### 14. Pronunciation: Proactive Audio on Every Card ✅
**Decision:** Azure Speech `it-IT-LunaNeural` reads the Italian side of every card proactively. Drew hears correct pronunciation on every exposure — not just pronunciation-specific cards.

- Vocab/phrase cards: audio attached automatically
- Pronunciation cards: reference audio sent before Drew attempts, then Azure phoneme scoring grades the attempt
- Reinforces correct pronunciation muscle memory on every interaction
- TTS audio cached as `.ogg` files — generate once per card, reuse forever. Cost effectively zero.
- **Azure Speech resource:** single key (`AZURE_SPEECH_KEY` + `AZURE_SPEECH_REGION`) covers both TTS and pronunciation assessment
- [ ] **Integration with Idoru infra** — Mission Control page design, cron jobs, Telegram bot flow
### 9. Content Source: Anki Decks ✅
**Decision:** Start with "Italian Travel and Small Talk for Beginners" (200 cards, audio), layer in top 500 frequency words from 5000+ deck.

**Details:**
- Anki decks are SQLite under the hood — extract and import into lingua.db
- Evaluate travel deck first, filter out useless vocab
- Frequency words provide core vocabulary foundation
- Total ~700 words to start (travel phrases + core vocab)

### 17. Card Validation: Import-Time + Daily Pre-Warm ✅
**Decision:** Two-stage validation pipeline — one-time import validation and daily pre-warm before review sessions.

**Stage 1: Import-time validation (one-time, on deck load)**
- Check for duplicate cards (same Italian text)
- Check for missing fields (no Italian text, no English text, no card type)
- Check for encoding issues (garbled characters, mojibake)
- Check Anki deck audio file integrity
- Flag suspicious entries for manual review (don't auto-import garbage)
- Log: "Imported N cards, flagged M for review, skipped K duplicates"

**Stage 2: Daily pre-warm (before review session)**
- Pull due cards from FSRS for the day
- Verify each card's data is intact (no DB corruption since import)
- Verify cached TTS audio files exist and aren't corrupted
- Generate any missing TTS audio via Azure Luna (before session starts)
- Verify Azure pronunciation reference text is present for pronunciation cards
- If any card fails validation → skip it, log it, don't send broken cards to Drew
- All audio pre-cached and ready before Drew says `pronto` — zero latency during review

**Flow:**
1. Morning cron fires → pull due cards from FSRS
2. Run validation pass on the batch
3. Pre-generate any missing TTS audio
4. Queue validated cards for the session
5. Send morning push: "☕ N cards due — type *pronto*"
6. Drew says `pronto` → cards ready, audio cached, zero wait

### 10. Card Types: 6 Types ✅
**Decision:** Vocabulary, Phrases, Grammar rules, Pronunciation, Production, Conversation.

**Card types:**
- **Vocabulary** — MC + typing (recognition + recall)
- **Phrases** — typing (produce the Italian)
- **Grammar rules** — sentence completion
- **Pronunciation** — see text → speak it → graded via Azure Pronunciation Assessment (phoneme-level scoring for it-IT). Drew gets per-sound accuracy feedback, not just pass/fail.
- **Production** — situation in English → produce Italian (typed or spoken)
- **Conversation** — multi-turn dialogue (LLM-judged) — **deferred to v1.1** (tracked in <https://github.com/dbradi1/idoru-lingua/issues/1>)

### 11. Card Volume: Progressive ✅
**Decision:** Lean early cities, denser later.

- Roma: ~60 cards (4 clusters × 15)
- Later cities: up to 120+ cards
- Total ~800-1000 cards across 8-10 cities

### 12. Content Generation: Seeded + Dynamic ✅
**Decision:** Bake Roma and Firenze fully before launch. Generate remaining cities dynamically as Drew approaches them.

- Allows tuning difficulty based on actual performance
- Prevents project from stalling on content creation
- First 2 cities are fully real at launch

### 18. No Reverse Cards ✅
**Decision:** All cards are production-forward (English → Italian). No reverse cards (Italian → English).

**Rationale:** Drew's goal is producing Italian, not translating it back to English. Recognition practice (seeing Italian and identifying it) happens naturally during pronunciation and production cards. Adding reverse cards doubles the FSRS load without serving the learning goal.

### 19. Leech Handling: Flag for Re-Learning ✅
**Decision:** Cards that keep failing (FSRS leeches) are flagged and pulled into a re-learning context, not auto-suspended.

**Flow:**
- FSRS detects a card has been failed N times (configurable threshold, default 5)
- Card is flagged as a leech and pulled from normal rotation
- Presented in re-learning mode: answer shown first, then tested again
- Once passed in re-learning, card returns to normal rotation with reset stability
- Lingua mentions leeches in session summary: "2 cards need extra work — they're in your re-learning queue"

### 20. Undo Support ✅
**Decision:** Drew can undo his last rating if he accidentally marks a card wrong.

**Trigger:** `annulla` (Italian for undo) or `undo`
- Reverts FSRS state to the previous value for the last graded card
- Only works for the most recent card in the current session
- Only one level of undo — can't undo multiple cards back

### 21. Skip Protection: Daily Review Cap ✅
**Decision:** Cap review sessions at a configurable number of cards (default 20) to handle gaps gracefully.

**Behavior after a gap (travel, sickness, etc.):**
- FSRS schedules all due cards naturally — no artificial penalty for missing days
- Session capped at 20 cards (configurable): "Welcome back — 23 cards due, let's do 20 today."
- Remaining cards stay due and get picked up next session
- No guilt messaging, no streak counter, no "you missed yesterday"
- Cap prevents the 147-card cliff after a week away

### 22. /explain Command ✅
**Decision:** `spiega` (Italian for explain) or `/explain` pulls up a concise grammar note for the current card's concept.

**Examples:**
- Card about *passato prossimo* → `/explain` gives 2-3 line refresher on when to use it vs *imperfetto*
- Card about *gli* sounds → `/explain` covers the palatal lateral approximant (how to actually make the sound)
- Card about *formal vs informal* → `/explain` summarizes when to use *Lei* vs *tu*

**Implementation:** Grammar notes stored alongside card metadata. No LLM call needed — pre-written explanations cached in the DB.

### 23. No Placement Test ✅
**Decision:** Skip placement test entirely. Start at Roma A1.1.

**Rationale:** Drew is a blank slate in Italian. Roma A1.1 is the right starting point. Placement tests are for learners with existing knowledge — not applicable here.

---

## Mission Control Page Design ✅

**Decision:** Dedicated Lingua page in Mission Control with map-dominant layout, matching the existing cyberpunk control-room aesthetic.

**Aesthetic:** Consistent with the rest of Mission Control — dark background (#0a0e1a), blue-purple accents (#7c3aed / #a78bfa), subtle grid overlay. "Mission planning hologram" energy, not Duolingo.

**Layout: map-dominant, data panels below.**

### Hero: Italy Route Map
- Full-width SVG map of Italy across the top — the first thing you see when the page loads
- 8 cities plotted on the route (Roma → Firenze → Bologna → Venezia → Verona → Napoli → Amalfi → Torino)
- Glowing animated route lines (dashed, flowing) between unlocked cities; dimmed dashed lines to locked cities
- City node states:
  - **Current city**: Pulsing purple node with glow halo, labeled "CURRENT"
  - **Completed cities**: Green node with ring, checkmark badge
  - **Locked cities**: Dimmed gray nodes with lock icon
- Click a city → side panels update to show that city's clusters and stats
- Legend in bottom corner: current / completed / locked / active route

### Three-Column Grid (below map)

**Left column — Memory Strength**
- City average percentage (large number, 36px)
- Gate status indicator: "✓ Gate reached (60%+) — Next city unlocked" or "× Gate not reached"
- Per-cluster strength bars:
  - Green: 85%+ (mastered)
  - Blue: 60–84% (on track)
  - Amber: 30–59% (learning)
  - Red: <30% (at-risk)
- Bars show the selected city's clusters (updates when map city is clicked)

**Center column — Review Activity**
- Cards due today (highlighted count)
- Last session summary (cards reviewed, score breakdown: ✓ good / ⬤ hard / ✗ again)
- Average session time
- Total reviews (all-time)
- Retention curve mini-chart (30-day FSRS retrievability trend)
- No streak counters, no XP, no guilt metrics

**Right column — System Health**
- Azure Speech (TTS) — connection status
- Azure Pronunciation Assessment — connection status
- lingua.db — card count, WAL mode indicator
- Morning Push Cron — schedule + last run
- Pre-warm Pipeline — cards ready for today
- Lingua Sub-agent — model (DeepSeek V4 Pro)
- Whisper (local) — status, port
- Leech Queue — flagged card count (amber if >0)

### Bottom Strip — Card Inventory
- Six-up stat grid: total cards, per-unlocked-city counts, locked cities total
- Type breakdown: Vocab / Phrases / Grammar / Pronunciation / Production
- Last import info (deck name, validation result)

### Explicitly excluded from v1
- Badge gallery — not essential at launch
- Heatmap — cluster bars already surface weak spots
- Real-time session viewer — Telegram is the session; MC is for post-review
- Streak counters or engagement metrics

### Mockup
A visual mockup of this design is saved at [`assets/mission-control-mockup.png`](assets/mission-control-mockup.png).

---

### 25. Daily Cron Pipeline: Pre-Warm + Morning Push ✅

**Decision:** Two staggered OpenClaw cron jobs — pre-warm at 6:50 AM ET, morning push at 7:00 AM ET. Pre-warm does the heavy lifting (validation, TTS generation, queue prep); push reads the ready queue and sends a Telegram message.

**Why two jobs instead of one:** Pre-warm can fail gracefully without Drew seeing a broken morning message. The push is a trivial operation that reads the ready queue and sends a message — it almost can't fail. If pre-warm has issues, the push adapts its message accordingly.

**Schedule:**
- **Pre-warm**: `50 6 * * *` (6:50 AM ET, America/New_York)
- **Morning push**: `0 7 * * *` (7:00 AM ET, America/New_York)
- 10-minute buffer between jobs — massive overkill in the normal case, but absorbs Azure degradation, DNS hiccups, and sub-agent startup delays

**Both jobs:** `sessionTarget: "isolated"`, `payload.kind: "agentTurn"`, model: `google/gemini-2.0-flash` (lightweight, same as other cron jobs — DeepSeek V4 Pro is for grading only)

#### Pre-Warm Pipeline (6:50 AM)

**Step 1 — Pull due cards from FSRS**
- Query `lingua.db` for all cards where FSRS due date ≤ today
- Sort by cluster weakness (weakest clusters first)
- Apply daily review cap (default 20 cards)

**Step 2 — Validate each card**
- SQL query per card: check for Italian text, English text, card type, valid FSRS state
- Sub-millisecond per card — full batch validates in under 1 second
- Cards that fail validation are skipped and logged (don't send broken cards to Drew)

**Step 3 — Check for missing TTS audio**
- File existence check for each card's cached `.ogg` file
- In steady state, zero missing (all audio generated at import time or card creation)
- This is a safety net, not the main path

**Step 4 — Generate missing audio (parallel)**
- Missing audio generated via Azure TTS (`it-IT-LunaNeural`) using async/parallel requests
- Per-request timeout: 30 seconds
- Parallel execution: all missing files generated concurrently, not sequential
- Hard timeout: 5 minutes (300 seconds) for the entire pre-warm job

**Step 5 — Verify pronunciation reference text**
- For pronunciation cards, verify reference text is present in DB
- If missing, skip the card and log it

**Step 6 — Queue validated cards**
- Write session record to `lingua.db`: session_id, due_card_ids, status: "pending_start", created_at
- Session waits for Drew to type `pronto`

**Audio generation strategy:** All TTS audio is generated at import time (840 cards ≈ 7 minutes one-time work). Pre-warm only generates missing audio as a safety net — in normal operation it finds nothing to generate.

#### Morning Push (7:00 AM)

- Read the pre-warmed session queue from `lingua.db`
- Check pre-warm status:
  - **Success**: Send "☕ N cards due — type *pronto* to start" to Lingua group chat
  - **Partial success**: Send "☕ N cards due — M ready, K skipped. Type *pronto* when you're ready."
  - **Zero due cards**: Send "☀️ Niente da fare oggi — no cards due! Enjoy the coffee break off. See you tomorrow."
  - **Pre-warm failed/timed out**: Send "☕ Italian coffee break is delayed today — technical issue. I'll have it ready shortly." and schedule retry pre-warm at 7:10 AM
- Store session state for sub-agent pickup (pending_card_id, timestamp)
- 10-minute timeout on the session — if Drew never says `pronto`, session expires

#### Failure Scenarios & Notifications

**Notification philosophy:** User impact, not system melodrama. Every notification answers: "Can I do my Italian review today or not?"

| Scenario | Detection | Impact | Notification | Action |
|----------|-----------|--------|--------------|--------|
| DNS resolution failure | Azure endpoints can't resolve | Can't generate missing audio or run pronunciation scoring | "☕ Pre-warm hit a network issue — DNS couldn't resolve Azure. Review will work but audio may be missing on some cards. Looking into it." | Retry once after 60s. If still failing, mark affected cards as "audio pending" and proceed text-only |
| Azure TTS slow/cold start | TTS calls exceed 30s per request or return 5xx | Missing audio on affected cards | "☕ Azure TTS is sluggish this morning. N cards missing audio — text-only review still works. I'll regenerate audio later." | Skip audio for affected cards, continue pre-warm. Log card IDs for later regeneration |
| Azure TTS complete outage | All TTS calls fail, or auth returns 401/403 | No new audio can be generated | "☕ Azure Speech is down — can't generate audio right now. Text-only review is ready, N cards due. I'll fix audio when Azure recovers." | Proceed text-only. Schedule retry pre-warm 15 min later |
| Azure Pronunciation outage | Pronunciation scoring API fails | Pronunciation cards can't be graded | "☕ Pronunciation scoring is temporarily unavailable. You can still do vocab and phrase cards — I'll queue pronunciation cards for later." | Filter pronunciation cards out of today's session, hold for next session |
| Ollama rate limiting (429) | Sub-agent model call returns 429 | Pre-warm sub-agent can't execute | "☕ Hit a rate limit on the AI provider — morning push will be a few minutes late. Retrying." | OpenClaw auto-retries with backoff. If 3 retries fail, send delayed notification |
| lingua.db corruption/lock | SQLite errors or lock beyond 10s | Can't read cards or session state | "⚠️ Lingua database issue this morning — can't load review cards. Working on it. Will let you know when it's fixed." | Hard blocker — no session possible. Log SQLite error. Retry in 15 min. If second failure, notify with specific error |
| Sub-agent startup timeout | No output within 90s of trigger | Pre-warm hasn't started | First occurrence: silent (OpenClaw retries). Second timeout: "☕ Morning Italian prep is running late — slight delay on your coffee break today." | OpenClaw auto-retries. If both fail, push job detects no ready queue and sends delayed message |
| Zero due cards (not a failure) | FSRS returns 0 due cards | Nothing to review | "☀️ Niente da fare oggi — no cards due! Enjoy the coffee break off. See you tomorrow." | Skip pre-warm entirely. Push sends nothing-due message. No session created |
| Pre-warm partial success | Some cards validated, some failed | Reduced session | "☕ N cards due — M ready, K skipped (audio generation issue). Type *pronto* when you're ready." | Push proceeds with valid cards. Skipped cards return to FSRS queue for tomorrow |
| Pre-warm complete failure | 0 valid cards or 5-min timeout | No session available | "☕ Italian coffee break is delayed today — technical issue. I'll have it ready shortly." | Schedule retry pre-warm at 7:10 AM. If retry also fails: "Still working on it — will let you know when your review is ready." Manual fix at that point |

#### Notification Routing
- All notifications go to the Lingua group chat (once created), or main Idoru chat as fallback
- No notifications during 11 PM – 6 AM (quiet hours) — push job handles messaging at 7 AM
- Critical failures (DB corruption, complete Azure outage) also logged to Mission Control diary

#### Session Handoff
- Cron writes session record to `lingua.db` (session_id, due_card_ids, status: "pending_start", created_at)
- Push message tells Drew to type `pronto`
- Lingua sub-agent sees `pronto` in the Lingua group chat, reads the pending session, starts serving cards
- 10-minute timeout on the session — if Drew never says `pronto`, session expires and cards return to queue

---

### 26. Primary Interface: Native iOS App (Swift) ✅

**Decision:** Build a native iOS app in Swift/SwiftUI as the primary interactive interface. Telegram becomes notification-only. Mission Control remains the web dashboard.

**Rationale:**
- We've invested heavily in architecture quality (FSRS, Azure phoneme scoring, 8-city progression, memory strength gauges) — the front-end should match that effort
- Telegram inline buttons and text messages are too constrained for a polished learning experience
- Native iOS gives us: smooth gesture-based card interactions, native audio recording/playback, visual pronunciation score breakdowns, animated progress gauges, the Italy map as an interactive element, push notifications
- This is a personal tool, not a mass-market app — no App Store deployment needed for v1 (free Apple Developer account runs on own device)

**Architecture impact:**

| Layer | Before (Telegram-primary) | Now (iOS-primary) |
|-------|---------------------------|-------------------|
| `lingua_engine.py` | Unchanged | Unchanged — still the headless core |
| API layer | Flask blueprint (MC only) | Thin REST API (FastAPI or Flask) serving both iOS app and Mission Control |
| Telegram | Primary interaction | Notification channel only — morning push, reminders, achievement notifications |
| Mission Control | Web dashboard | Web dashboard (unchanged) |
| iOS app | Not planned | Primary interactive interface |

**Build workflow:**
- Idoru writes all Swift code (views, models, networking, audio, everything)
- Drew compiles and tests on MacBook Pro using Xcode (Issue #4)
- Drew sends screenshots/error logs → Idoru iterates and fixes
- Same division of labor as Mission Control (Idoru writes, Drew deploys)

**What Telegram still does (notification layer):**
- Morning push notification: "☕ 8 cards due — open the app to start"
- Session reminders if overdue cards pile up
- Achievement notifications (city arrival, badge earned)
- System status (pre-warm failures, etc. per Decision #25 failure matrix)
- No card rendering, no grading, no interactive flow — just nudges to open the app

**What the iOS app handles:**
- Card rendering (all 5 active card types: vocab, phrases, grammar, pronunciation, production)
- Audio playback (Azure Luna TTS reference audio)
- Audio recording (Drew's pronunciation attempts)
- Gesture-based rating (swipe or tap — again/hard/good/easy)
- Visual Italy map with city progression
- Memory Strength gauges and retention charts
- Pronunciation score visualization (phoneme-level breakdown)
- On-demand review sessions (replaces `quiz me` / `pronto`)
- Session summary screen
- `spiega` (explain) — tap to see grammar note for current card
- `annulla` (undo) — undo last rating

**What stays in the engine (not in the app):**
- FSRS scheduling logic
- Azure TTS generation (server-side, audio files served via API)
- Azure Pronunciation Assessment scoring (server-side, app sends audio → server scores → returns results)
- lingua.db operations
- Pre-warm pipeline (cron)
- Card validation
- Leech detection
- Progression gate logic

**Tech stack:**
- Swift + SwiftUI (iOS 17+ target)
- URLSession for API calls
- AVAudioEngine for pronunciation recording
- AVAudioPlayer for reference audio playback
- UserNotifications framework for push (morning reminders)
- Server: FastAPI or Flask thin API layer (same host as Mission Control, different port or path prefix)

**Affected prior decisions:**
- **Decision #4** (Telegram Flow): Telegram is now notification-only, not the interactive session flow. The sequential card flow moves to the app. Trigger words (`pronto`, `basta`) become in-app actions, not Telegram messages. `spiega` and `annulla` remain as concepts but are app UI interactions.
- **Decision #6** (Delivery): Updated delivery model — iOS app (primary) + Telegram (notifications) + Mission Control (dashboard). No separate standalone UI needed — the app IS the standalone UI.
- **Decision #7** (Scheduling): Morning push now says "open the app" instead of "type pronto." On-demand quizzes happen in-app, not via Telegram `quiz me`.
- **Decision #25** (Cron Pipeline): Push message format changes from "type *pronto*" to "open the app to start." Pre-warm pipeline unchanged. Failure notifications still go to Telegram (that's the right channel for system alerts).

---

### 27. iOS App Design: Screens, Navigation & Visual Identity ✅

**Decision:** Tab-based SwiftUI app with 4 tabs, warm Italian aesthetic, 5 card type layouts, gesture-based rating.

#### Visual Identity: Warm Italian

A daily ritual aesthetic — feels like opening a café journal in a piazza, not a control room.

**Color palette:**
- Background: Cream/parchment (#FAF3E7 in light, #1C1714 in dark)
- Primary accent: Terracotta (#C65D3A) — buttons, progress, active states
- Secondary accent: Mediterranean blue (#2D6A8E) — links, secondary actions, stats
- Success: Olive green (#6B8E4E) — correct answers, mastered clusters
- Warning: Amber (#D4A02E) — hard ratings, at-risk clusters
- Error: Brick red (#A03B2E) — wrong answers, leeches
- Text: Deep brown (#2D2014 in light, #E8DCC8 in dark)
- Cards/surfaces: Warm white (#FFFFFF in light, #2A2118 in dark) with subtle warm shadow

**Typography:**
- Headlines: Rounded, warm serif (e.g., system rounded or Georgia) — feels handwritten, personal
- Body: System sans (San Francisco on iOS) — clean, readable
- Italian text: Italic serif for Italian phrases — reinforces "this is the language you're learning"
- Numbers/stats: Monospaced for alignment

**Texture & feel:**
- Subtle paper-grain texture on backgrounds (very low opacity)
- Cards have soft shadows, rounded corners (16pt radius)
- Smooth spring animations on card transitions, not linear fades
- No neon, no glow effects — this is warm and tactile

#### Navigation Structure

4-tab structure (bottom tab bar):

**Tab 1 — Home (Review)**
Default launch screen. The daily driver.
- Greeting header: "Buongiorno, Drew" with current city name and flag emoji
- Due cards count: Large number — "8 cards ready" with prominent terracotta "Pronto →" button
- Memory Strength ring: Circular gauge showing overall strength across all cities
- Current city card: City name, progress bar, cluster breakdown mini-bars, gate status badge
- Quick stats: Last session summary (if any), total reviews count — no streaks, no XP
- When session active → transitions to full-screen Card View
- When session ends → shows Session Summary, then returns to Home

**Tab 2 — Journey (Italy Map)**
The visual progression page — the adventure screen.
- Interactive Italy map: Touch-optimized SVG. Pinch to zoom, tap a city to select.
- Route visualization: Warm terracotta path between unlocked cities, dashed gray to locked cities
- City nodes: Current city (pulsing terracotta), completed (olive green ring), locked (gray, dimmed)
- City detail sheet (slides up from bottom on tap):
  - City name, CEFR level, badge name
  - Memory Strength gauge (city average)
  - Skill clusters with individual strength bars (olive/blue/amber/brick color-coded)
  - Gate status: "✓ Gate reached — next city unlocked" or "× 2 clusters below 30%"
  - Card count and type breakdown for this city
- This is the screen that makes it feel like an adventure, not a flashcard app

**Tab 3 — Stats (Progress)**
The data dashboard.
- Retention curve: FSRS retrievability over time (30/90/all-time toggle)
- Review history: Bar chart of cards reviewed per day
- Cluster strength grid: All clusters across all cities, color-coded heat grid
- Leech queue: Flagged cards count with "Review Leeches" button
- Card type breakdown: Distribution chart (vocab/phrases/grammar/pronunciation/production)
- Achievement timeline: Badges earned, cities unlocked, milestones reached

**Tab 4 — Practice (On-Demand)**
Quick access to study outside scheduled reviews.
- Quiz Me: Start on-demand session from due cards (same card flow as morning session)
- Leech Review: Jump into re-learning queue directly
- Free Practice: Browse cards by city/cluster without FSRS grading (casual review)
- Pronunciation Drill: Practice pronunciation cards specifically with Azure scoring
- Settings: API server URL, audio preferences, daily review cap, notification schedule, dark/light mode toggle

#### Card View (Full-Screen, Launched from Home or Practice)

Core interaction screen — card-by-card learning flow.

**Universal card chrome:**
- Top bar: City name + cluster name + card counter ("3 of 8") + close button (×)
- Card body: Varies by type (see below)
- Bottom: Action area (answer input, rating buttons, or audio recorder)
- Spiega button: Always visible (small icon, bottom-left) — tap for grammar note overlay
- Annulla button: Appears briefly after rating — undo last card

**Card type layouts:**

1. **Vocabulary card**
   - English word/phrase displayed prominently (serif italic for emphasis)
   - Audio button (speaker icon — tap to hear Azure Luna Italian pronunciation)
   - 4 multiple-choice Italian options as tappable rounded cards
   - Tap correct → olive green flash + brief feedback → next card
   - Tap wrong → brick red flash + correct answer shown with explanation → next card

2. **Phrase card**
   - English phrase displayed
   - Audio button for reference pronunciation
   - Text field for typing Italian answer (auto-correct disabled)
   - Submit button → LLM grades via API → feedback with corrections

3. **Grammar card**
   - Sentence with blank, context hint (tense, conjugation type)
   - Audio button for full correct sentence
   - Multiple choice or text input depending on complexity

4. **Pronunciation card**
   - Italian text displayed (large, serif italic)
   - "Tap to hear" reference audio button
   - Microphone button — hold to record, release to submit
   - Live waveform visualization while recording
   - After scoring: phoneme breakdown appears as horizontal bars per sound
   - Per-sound accuracy: "gli: 45% · r: 92% · o: 88%" with color-coded bars
   - Overall pronunciation score with color indicator (olive/amber/brick)

5. **Production card**
   - Situation described in English
   - Toggle: ✍️ type or 🎤 speak answer
   - If speak: records → Whisper transcribes (server-side) → LLM grades
   - Feedback with corrections and natural alternatives

**Rating interaction (after answering):**
- Multiple choice cards: auto-graded, shows result with color animation, "Next →" button
- Typed/spoken cards: self-rating via gesture:
  - Swipe left: Again (brick red flash)
  - Swipe up: Hard (amber flash)
  - Swipe right: Good (olive green flash)
  - Double-tap: Easy (Mediterranean blue flash)
- Next card slides in with spring animation after rating
- If last card → transitions to Session Summary

**Session Summary screen:**
- Cards reviewed: count with breakdown (✓ good / ⬤ hard / ✗ again)
- Memory Strength change: "Roma: 72% → 75% (+3%)" with arrow
- Time taken (e.g., "4m 20s")
- Leeches detected (if any): "2 cards need extra work — they're in your re-learning queue"
- Cluster movement: any clusters that changed color tier
- "Done" button returns to Home (which now shows updated stats)

#### Onboarding (First Launch)
- Welcome screen: "Benvenuto a Idoru Lingua" with logo and brief intro
- Server setup: Enter API URL (defaults to Tailscale address of ThinkPad)
- No placement test (per Decision #23) — starts at Roma A1.1
- Brief tour of the 4 tabs (3-4 slides, skippable)
- Push notification permission request
- Straight to Home screen with 0 cards due (nothing imported yet)

#### Dark Mode
- Warm dark palette (not black — warm dark brown #1C1714 background)
- Terracotta stays as primary accent, slightly brightened for contrast
- Card surfaces: #2A2118 (warm dark, not cold gray)
- Text: #E8DCC8 (warm cream)
- Automatic switch with system setting, manual override in Settings
---

### 28. API Layer: FastAPI + Thin REST ✅

**Decision:** Build a thin REST API using FastAPI on the ThinkPad, serving both the iOS app and Mission Control dashboard. Runs alongside Mission Control's Flask app as a separate service.

**Why FastAPI over Flask:**
- Async-native — matters for pronunciation scoring (upload audio → wait for Azure → return scores) without blocking other requests
- Auto-generated OpenAPI docs — clean contract between server and Swift app, can auto-generate Swift models from the API spec
- Built-in request validation via Pydantic — catches malformed requests before they hit the engine
- Separate service from Mission Control — no risk of breaking existing Flask app during development

**Service configuration:**
- Port: 5051 (Mission Control stays on 5050)
- Bound to Tailscale IP only (100.66.129.43) — not 0.0.0.0, not localhost
- systemd service: `idoru-lingua-api.service`
- Imports `lingua_engine.py` directly as a Python library (same process, no inter-process communication)
- Python 3.12+ (matches existing Idoru infra)
- Secrets from `/home/drew/.env` (AZURE_SPEECH_KEY, AZURE_SPEECH_REGION, etc.)

**Authentication:**
- Simple API key — generated once, stored in iOS app's Keychain
- Sent as `Authorization: Bearer <key>` header on every request
- Key stored server-side in `lingua.db` or config file
- No OAuth, no user accounts — single-user app over Tailscale
- Middleware validates key on every request, returns 401 if missing/invalid

**Versioning:**
- All endpoints prefixed with `/api/v1/`
- Future breaking changes → `/api/v2/`, old app keeps working against v1

#### Endpoints

**Session management:**
- `GET /api/v1/session/due` — get due cards for today (calls `get_due_cards()`)
- `POST /api/v1/session/start` — start a session, returns session_id + first card
- `POST /api/v1/session/{id}/submit` — submit answer for current card, returns grade + next card
- `POST /api/v1/session/{id}/undo` — undo last rating (calls `undo_last_rating()`)
- `POST /api/v1/session/{id}/end` — end session, returns summary

**Card interaction:**
- `GET /api/v1/card/{id}/audio` — serve cached `.ogg` audio file (or 404 if not yet generated)
- `GET /api/v1/card/{id}/explain` — get grammar note (calls `get_card_explanation()`)
- `POST /api/v1/pronunciation/assess` — upload audio + reference text, returns phoneme scores (calls `assess_pronunciation()`)

**Progression:**
- `GET /api/v1/progress/overview` — overall stats, current city, Memory Strength (calls `get_city_progress()` for all cities)
- `GET /api/v1/progress/city/{id}` — city detail with cluster breakdown
- `GET /api/v1/progress/clusters/{city_id}` — cluster strengths (calls `get_cluster_strength()`)

**Stats:**
- `GET /api/v1/stats/retention?range=30d` — retention curve data points
- `GET /api/v1/stats/history?range=30d` — daily review counts
- `GET /api/v1/stats/leeches` — leech queue contents

**Practice:**
- `GET /api/v1/practice/quiz` — on-demand due cards (same as session/due but not tied to morning push)
- `GET /api/v1/practice/free/{city_id}` — browse cards without FSRS grading (casual review)
- `GET /api/v1/practice/pronunciation` — pronunciation cards specifically

**Settings:**
- `GET /api/v1/settings` — daily cap, notification schedule, audio preferences
- `PATCH /api/v1/settings` — update settings

#### Pronunciation Flow (latency-critical)

1. App records audio (m4a/wav on iOS via AVAudioEngine)
2. App uploads to `POST /api/v1/pronunciation/assess` as multipart form data (audio file + reference text)
3. Server calls Azure Pronunciation Assessment via `lingua_engine.py`
4. Server returns JSON: `{ overall_score: 78, phonemes: [{ sound: "gli", score: 45 }, { sound: "r", score: 92 }, ...] }`
5. App renders phoneme score bars
- **Target latency:** under 3 seconds end-to-end
- App shows loading state with waveform animation while waiting
- Server-side timeout: 30 seconds for Azure response (returns 504 if exceeded)

#### Error Handling — App Side

The app must handle network failures gracefully. Drew opens this app over coffee every morning — it should never crash, show a blank screen, or display a raw stack trace.

**Connection failures (Tailscale down, ThinkPad offline, network unreachable):**
- Detected when: URLSession requests time out or can't resolve/connect
- App behavior:
  - Home tab: Show warm-toned offline banner — "🔇 Can't reach Idoru Lingua server. Check that Tailscale is connected on your iPhone." with a "Retry" button
  - Card view: If mid-session and connection drops, show "Connection lost. Your progress is saved. Reconnect to continue." — graded cards are already submitted, ungraded card stays pending
  - Journey/Stats tabs: Show last cached data with a subtle "offline — showing last sync" indicator. Stale data is better than an empty screen.
  - Practice tab: Disable action buttons, show "Requires connection"
- The app caches the last successful API response for each tab locally (UserDefaults or Core Data) so there's always something to show
- Automatic retry: every 30 seconds while offline, silent until reconnected
- On reconnect: sync any pending session state, dismiss offline banner with a brief "✓ Reconnected" toast

**API error responses:**

| HTTP Status | Meaning | App behavior |
|-------------|---------|--------------|
| 200 | Success | Normal rendering |
| 401 | Invalid API key | Show "Authentication failed — check API key in Settings" |
| 404 | Card/resource not found | Skip item, log, continue session if possible |
| 422 | Validation error (malformed request) | Show "Something went wrong with that request" (non-technical) |
| 500 | Server error | Show "Server error — Idoru is looking into it. Try again in a moment." |
| 504 | Azure timeout (pronunciation only) | Show "Pronunciation scoring is taking too long. Try again." — don't lose the card |
| Timeout | Tailscale down / network unreachable | Show offline banner (see above) |

**Mid-session recovery:**
- If connection drops during a card submission: the app holds the answer locally and retries on reconnect
- If connection drops between cards: next card request retries automatically
- If the app is force-closed mid-session: on next launch, app checks for active session via `GET /api/v1/session/due` and offers to resume
- Session state of record is always server-side (lingua.db) — the app is a thin client, never the source of truth for FSRS state

**Server-side error handling:**
- All endpoints wrapped in try/except — returns JSON error with `{ error: string, code: string }` format
- Errors logged to `~/.idoru-lingua-api.log` (same pattern as other Idoru services)
- Azure failures during pronunciation scoring: return 504 with helpful message, don't crash the API process
- lingua.db errors: return 500, log the SQLite error, notify Idoru via diary entry
- If the API service itself crashes: systemd auto-restarts (same pattern as Mission Control)

**No rate limiting (v1):**
- Single-user app over Tailscale — not needed
- If ever exposed beyond Tailscale, add rate limiting at that point
