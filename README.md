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

## Still To Decide

- [ ] **Tech Stack** — Python headless library (`lingua_engine.py`) with clean API; Flask blueprint in Mission Control for dashboard
- [ ] **Dedicated Lingua sub-agent** — create `lingua` agent in OpenClaw config with model override (`ollama/deepseek-v4-pro`). Handles Lingua group chat autonomously. Needed for v1 grading (inline API calls) and v1.1 conversation cards (multi-turn dialogue with persona).
- [ ] **Azure Speech resource** — create one in Azure portal, add key to `/home/drew/.env`
- [ ] **Telegram Lingua group chat** — Drew to create dedicated group chat for all Lingua interaction
- [ ] **Integration with Idoru infra** — Mission Control page design, cron jobs, Telegram bot flow
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