# Reel Mode

A vertical, TikTok-style feed. Each card is a game, a question or a quick read. A card must be finished (game over, answer given, "Got it" tapped) before the player can scroll to the next one. The next card is hidden behind a "?" peek, so it cannot be predicted. No going back.

## Rules
- Next-card mix: weighted random with guard rails. First card is a game, never more than 2 games in a row, never 3 non-games in a row, a game never repeats within the last 2 games.
- Learning order: questions and reads follow the modules in order, lesson by lesson (a lesson's reads, then its questions). A wrong answer comes back a few learning cards later, once. After the last lesson it loops.
- **No dead screen and no second chance in the reel.** When a game ends the player sees the results screen (score and best score). Scrolling is then unlocked. No "play again" either: the reel moves on.
- Every game card shows its game's **best score** next to the **current score** while playing, and both on the results screen.
- Scrolling is locked while a game is being played, so vertical game swipes never fight the page.
- Quiz chip (the non-blocking power-up question during a run) stays on in the reel.

## Pieces (lib/features/reel/)
| File | Job |
|---|---|
| `reel_item.dart` | `ReelItem` (game / question / read), `ReelCursor`, `ReelDone` |
| `reel_feed.dart` | `ReelFeed` interface, `reelFeedProvider` |
| `reel_extra.dart` | `ReelExtra` and its provider (`assets/content/reel_extra.json`) |
| `reel_sequencer.dart` | `ReelSequencer implements ReelFeed` and the real `reelFeedProvider` |
| `reel_screen.dart`, `gated_physics.dart` | Vertical pager, scroll gating, top bar, swipe cue |
| `cards/game_card.dart`, `question_card.dart`, `read_card.dart` | One card per item type; each calls `onDone` once |

Game cards embed `GameRun` (extracted from `GameHostScreen` in `lib/features/games/_shared/`), so Arcade, Story and Reel share the same game flow.

## Extra content (`assets/content/reel_extra.json`)
Draft content for the reel only, written fast; the whole content set is audited later.
```
{"reads":[{"lesson":"mf-basics-1","emoji":"💡","title":"...","body":"..."}],
 "questions":[{"lesson":"mf-basics-1","id":"mf-basics-1-x1","type":"trueFalse","topic":"mf-basics",
               "difficulty":1,"explanation":"...","payload":{"statement":"...","answer":true}}]}
```
