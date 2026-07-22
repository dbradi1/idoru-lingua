# Idoru Lingua — Command Reference

All commands are typed in the Lingua Telegram group chat. Italian trigger words are primary; English aliases noted where available.

---

## Session Commands

| Command | Italian | Description |
|---------|---------|-------------|
| `pronto` | "ready" | Start a review session — begins serving due cards one at a time |
| `basta` | "enough" | Stop the current session mid-review. Progress is saved. |
| `quiz me` | — | Start an on-demand review session (same flow as morning push, any time) |

## Card Commands

| Command | Italian | Description |
|---------|---------|-------------|
| `spiega` | "explain" | Pull up a concise grammar note for the current card's concept |
| `/explain` | — | English alias for `spiega` |
| `annulla` | "undo" | Undo the last card rating (if you accidentally marked it wrong) |
| `undo` | — | English alias for `annulla` |

## Command Details

### `pronto`
- Starts a review session using the pre-warmed card queue
- If no pre-warmed session exists (e.g., on-demand outside morning hours), pulls due cards from FSRS on the fly
- Cards are served one at a time with audio attached
- Only one card pending at a time — no batch ambiguity

### `basta`
- Stops the current session immediately
- All graded cards so far are saved to FSRS
- Session summary sent: "15 cards reviewed: 12 good, 2 hard, 1 again. Roma: 72% (+3%)"
- Remaining due cards stay in the queue for next session

### `quiz me`
- Same sequential flow as `pronto`, but available any time
- Pulls from the same FSRS due-card queue
- Useful for a quick session outside the morning push

### `spiega` / `/explain`
- Shows a 2-3 line grammar refresher for the current card's concept
- Pre-written explanations cached in the database — no LLM call needed
- Examples:
  - Card about *passato prossimo* → refresher on when to use it vs *imperfetto*
  - Card about *gli* sounds → how to actually make the palatal lateral approximant
  - Card about *formal vs informal* → when to use *Lei* vs *tu*

### `annulla` / `undo`
- Reverts FSRS state to the previous value for the last graded card
- Only works for the most recent card in the current session
- Only one level of undo — can't undo multiple cards back

## Rating Cards

After answering a card, you rate your response. These aren't typed commands — they're selected from inline buttons or typed as short responses:

| Rating | Meaning | FSRS Effect |
|--------|---------|-------------|
| `again` | Completely forgot | Reset stability, re-show soon |
| `hard` | Got it but struggled | Small stability increase, shorter next interval |
| `good` | Knew it | Normal stability increase, standard next interval |
| `easy` | Knew it instantly | Large stability increase, longer next interval |

## Notes

- All commands are case-insensitive
- Italian trigger words are the primary interface — learning the commands is part of learning the language
- English aliases exist as a safety net while you're still learning
- Only one session active at a time per user
- 10-minute timeout per card during a session — if no response, card is marked "skipped" (not failed) and returns to the queue