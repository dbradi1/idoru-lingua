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

### 3. Grading: Mixed (LLM + Multiple Choice) ✅
**Decision:** LLM judging for free-form answers, multiple choice for quick vocab, transcription matching for voice.

**Details:**
- Free-form text/voice answers → LLM grades correctness + provides feedback
- Multiple choice for quick recognition drills (keeps API cost down)
- Voice answers transcribed via local Whisper, compared against expected answer
- Pronunciation scoring: v1 uses transcription matching; v2 could add phoneme-level model (Azure/Google Speech)

### 4. Voice Input Handling: Card Context + Explicit Trigger ✅
**Decision:** Card context determines intent, with explicit trigger as fallback.

**Flow:**
- If I just sent you a card and you respond (voice or text) within 5 min → treated as answer
- If no active card → say "quiz me" or "Italian time" to start a session
- Language detection (Italian vs English) considered but rejected as fragile

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

### 8. Progression: Mastery + Exploration ✅
**Decision:** Move forward with gaps; badges reward depth.

**Thresholds:**
- **Explore next city:** current city clusters average ≥60%
- **Mastered badge:** all clusters in a city hit ≥85%
- Weak spots visible on the map but don't gate progression

---

## Still To Decide

- [ ] **Content/Curriculum** — what vocabulary and grammar per city, sourced from where
- [ ] **Tech Stack** — what we build the engine in (Python? FastAPI? How does the FSRS library integrate?)
- [ ] **Integration with Idoru infra** — Mission Control page design, cron jobs, Telegram bot flow
- [ ] **City map** — which cities, in what order, what language milestones each represents
- [ ] **Initial content seeding** — how do we populate the first set of cards