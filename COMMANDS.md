# Idoru Lingua — Command Reference

All commands are in-app actions within the native iOS app. Italian naming is preserved — learning the commands is part of learning the language.

---

## Session Actions

| Action | Italian | How | Description |
|--------|---------|-----|-------------|
| Start session | `pronto` | Tap "Start Review" on home screen | Begins serving due cards one at a time |
| Stop session | `basta` | Tap "End Session" button | Stops mid-review. Progress is saved. |
| On-demand quiz | — | Tap "Quiz Me" on home screen | Start a review session any time, same card flow |

## Card Actions

| Action | Italian | How | Description |
|---------|---------|-----|-------------|
| Explain | `spiega` | Tap "Spiega" button on any card | Pull up a concise grammar note for the current card's concept |
| Undo | `annulla` | Tap "Annulla" button (after grading) | Undo the last card rating (if you accidentally marked it wrong) |

## Action Details

### Start Session (`pronto`)
- Starts a review session using the pre-warmed card queue from the morning cron pipeline
- If no pre-warmed session exists (e.g., on-demand outside morning hours), pulls due cards from FSRS on the fly
- Cards are served one at a time with audio attached
- Only one card pending at a time — no batch ambiguity

### Stop Session (`basta`)
- Stops the current session immediately
- All graded cards so far are saved to FSRS
- Session summary screen shows: "15 cards reviewed: 12 good, 2 hard, 1 again. Roma: 72% (+3%)"
- Remaining due cards stay in the queue for next session

### On-Demand Quiz
- Same card flow as a morning session, but available any time
- Pulls from the same FSRS due-card queue
- Useful for a quick session outside the morning push

### Explain (`spiega`)
- Shows a 2-3 line grammar refresher for the current card's concept
- Pre-written explanations cached in the database — no LLM call needed
- Examples:
  - Card about *passato prossimo* → refresher on when to use it vs *imperfetto*
  - Card about *gli* sounds → how to actually make the palatal lateral approximant
  - Card about *formal vs informal* → when to use *Lei* vs *tu*

### Undo (`annulla`)
- Reverts FSRS state to the previous value for the last graded card
- Only works for the most recent card in the current session
- Only one level of undo — can't undo multiple cards back

## Rating Cards

After answering a card, rate your response. In the iOS app, this is a gesture or tap interaction:

| Rating | Gesture | Meaning | FSRS Effect |
|--------|---------|---------|-------------|
| Again | Swipe left | Completely forgot | Reset stability, re-show soon |
| Hard | Swipe up | Got it but struggled | Small stability increase, shorter next interval |
| Good | Swipe right | Knew it | Normal stability increase, standard next interval |
| Easy | Double-tap | Knew it instantly | Large stability increase, longer next interval |

## Telegram (Notification Channel Only)

Telegram is no longer the interactive interface — that's the iOS app. Telegram still handles:

| Notification | Trigger | Example |
|-------------|---------|---------|
| Morning push | Cron pipeline (7 AM ET) | "☕ 8 cards due — open the app to start" |
| Overdue reminder | Cards piling up 3+ days | "📅 You've got 23 cards overdue. Open the app when you get a chance." |
| Achievement | City arrival / badge earned | "🏛️ You've reached Roma! Badge unlocked: Found your feet in the Eternal City" |
| System issue | Pre-warm failure (per Decision #25) | "☕ Italian coffee break is delayed today — technical issue." |

## Notes

- All in-app action labels use Italian words — learning the UI is part of the immersion
- Only one session active at a time per user
- 10-minute timeout per card during a session — if no response, card is marked "skipped" (not failed) and returns to the queue
- Italian action names are the primary labels; small English subtitles may appear below for the first few sessions until familiarity builds