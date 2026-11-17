# Roadmap: v1.1 to v2.0

North star: the most replayable investor-education game there is. A player should open it daily because the games are good, and leave knowing more each time. Retention comes from mastery, collection and streaks, never from tricks that cost the player money or sleep.

Status key: ✔ shipped, ○ planned.

---

## v1.1 "Fresh Paint" ✔ shipped in v1.2.0 (aesthetic only, plus two arcade flow fixes)

Spec: [DESIGN.md](DESIGN.md).

### 1.1.1 Design system (`lib/core`)
- [x] Replace colour tokens with the Bazaar Board palette. Remove violet. Freeze the old palette as `ArcadeColors` for the three existing game canvases.
- [x] Add Baloo 2 as the display face. Rebuild the text theme (display 40/32/26, title 20/17, body 16/14, label 13/11).
- [x] Rebuild `Panel`, `ChunkyButton`, `StatPill`, `FatProgress`, `Badge3D` as outlined pieces with hard shadows. Press responds on touch-down.
- [x] New pieces: `Pressable`, `Tilt3D`, `PopIn`, `CountUp`, `Coin3D`, `OutlinedText`, `PaperBackground` (dot grid).
- [x] `Sound` service and 15 synthesised effects. Mute toggle stored in preferences.
- Done when: no `Gradient` or blurred shadow remains in `lib/core`, the layout test passes at 360x640 and text scale 1.3.

### 1.1.2 Home, shell, profile
- [x] Hero: an isometric **Portfolio Town** drawn in code. One building per completed module and chapter, height grows with level, small idle animation (windows, a moving cloud, a coin above the newest building). Tilts with the finger.
- [x] Header: level medal with roll-up XP, streak flame, spinning `Coin3D` balance.
- [x] Mode tiles as three board tiles (Story, Arcade, Learn), each a different colour block with a painted icon, tilt on touch, pop-in on first paint.
- [x] Daily question as a ticket stub with a perforated edge.
- [x] Custom bottom bar: four ink-outlined tabs, the active one raised and coloured, spring between tabs.
- [x] Profile: player card with medal, stat blocks, high-score ladder, sound toggle.
- Done when: a first-time screenshot of Home has one clear hero, zero gradients, zero emoji in chrome.

### 1.1.3 Learn and quiz
- [x] Module cards as book spines or folders with a progress tab. Lesson rows as numbered stepping stones.
- [x] Lesson cards flip in 3D between front (idea) and back (example) and stack like a deck with the next card peeking.
- [x] Question pieces: option tiles press down, correct tile jumps and turns green, wrong tile shakes and turns red, both with sound.
- [x] Myth/fact card gets a rubber stamp that slams down (scale and rotation spring).
- [x] Summary: medal drop, XP roll-up, three-star rating by accuracy.

### 1.1.4 Story
- [x] Map as a board path: tiles to step along, chapter stops as raised buildings, the player token hops to the current stop.
- [x] Dialogue: flat illustrated backdrop per chapter (paper cut-out layers with parallax on tilt), comic speech bubbles with ink outline and tail.
- [x] Chapter list as a ticket strip. Reward scene: chest opens, coins arc into the balance.

### 1.1.5 Arcade flow
- [x] Non-blocking quiz chip (run never pauses).
- [x] Optional second chance on the results screen.
- [x] "What you learned this run" list on results.
- [x] Host HUD, intro, pause and results in the new style. Score in outlined display type.

Release gate: all tests green, screenshots of every screen reviewed against DESIGN.md, APK published as `v1.1.0`.

---

## v1.2 "Arcade Pack" ✔ shipped in v1.2.0 (more games, sound everywhere)

- [x] **Brick Bank** (breakout): paddle, ball, vault bricks with hit points, falling pickups, multi-ball. Boost orb every 20 bricks.
- [x] **Candle Hop** (one-tap flyer): fly a rocket through gaps between red and green candlesticks. Gap narrows with distance. Coins in the gaps.
- [x] **Coin Slash** (slicer): swipe to slice flying coins, avoid scam bombs, combo multiplier for multi-slices, three lives.
- [x] Sound and haptics wired into all six games and the host (tap, coin, powerup, crash, perfect, merge, win, lose).
- [x] Existing games: visual pass so tiles, blocks and pickups share the outlined-piece look where it fits their world.
- [x] Arcade tab: game shelf with best score, a "new" tag, and a daily featured game. (Double coins for the featured game: not built, moved to v1.3.)
- Release gate: each game has unit tests for its rules and a 600-frame smoke test, is playable one-handed, and holds 60 fps in the web build. APK `v1.2.0`.

---

## v1.3 "The Loop" ○ (retention)

- [ ] **Daily quests**: three per day from a pool (play 2 games, finish 1 lesson, 3 correct in a row, beat a best). Chest on completing all three.
- [ ] **Chests** with visible odds: coins, power-ups, card packs. Opening is a 3D lid animation.
- [ ] **Collectible cards**: 40 concept cards (NAV, SIP, Expense Ratio, the Fund Zoo animals) in common, rare and gold. Album screen. A card unlocks by mastering its concept, not by luck alone.
- [ ] **Streak**: streak freeze (bought with coins, one held at a time), milestone rewards at 3, 7, 14, 30 days, streak repair by a review quiz.
- [ ] **Spaced review**: questions answered wrong come back after 1, 3 and 7 days in a two-minute "Review" session.
- [ ] **Shop**: power-up loadouts before a run, town decorations, player tokens. Coins only, no real money.
- [ ] **Mastery levels per game**: bronze to gold score targets with one-time rewards.
- [ ] **Near-miss and progress messages** on results ("12 metres from your best").
- [ ] Local notifications: streak reminder at the player's usual play hour, opt-in.
- Metrics to watch: D1, D7, sessions per day, quests completed, lessons per session.

## v1.4 "Together" ○ (social and trust)

- [ ] Google sign-in, progress moves between devices. Move to the Firebase SDKs.
- [ ] Cloud Functions validate game results and own XP and coins.
- [ ] Weekly leagues of 30 players by XP, promotion and relegation.
- [ ] Friend codes, friend leaderboard, async challenges with the same seed.
- [ ] Share cards (image) for chapter completions and bests.

## v1.5 "More to Learn" ○ (content depth)

- [ ] Story chapters 4 to 8: reading the label (costs, direct vs regular), storm season (volatility), goal quest (asset allocation), tax basics, the final portfolio.
- [ ] Five new modules: costs and loads, risk and volatility, goals and allocation, taxation basics, reading a factsheet.
- [ ] New question types: order-it, numeric slider, spot the red flag.
- [ ] Adaptive difficulty from answer history.
- [ ] Hindi, then two regional languages. Baloo 2 already covers Devanagari.
- [ ] Content admin tool and Firestore-hosted content with the bundle as fallback.
- [ ] Subject-matter and compliance review of all content. Gate for any public launch.

## v2.0 "Launch" ○

- [ ] 3D showcase game (Unity embedded or a Flame pseudo-3D upgrade), behind a device-tier flag.
- [ ] iOS build and TestFlight.
- [ ] Music, full sound design by a sound designer.
- [ ] Accessibility audit, performance budget on a low-end Android phone.
- [ ] Privacy policy, consent, age gate. Play Store and App Store submission.

---

## Guardrails for "addictive"

- No real-money purchases, no paid randomness, odds always shown.
- Session-length nudge after 30 minutes.
- Notifications are opt-in and capped at one per day.
- Every reward loop is tied to learning or skill, not to waiting.
