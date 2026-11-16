# Brief for agents working on this repo

Investor-education game (mutual funds, India). Flutter + Flame + Riverpod + go_router. Three modes: Arcade (pure game), Story, Learn (pure edu). Goal: the best-looking, most replayable game of its kind. At this stage game feel and visual quality come first.

**Read `docs/DESIGN.md` before anything else.** It is the visual law: the "Bazaar Board" theme (warm paper, solid colour, thick ink outlines, hard offset shadows, 3D pieces, spring motion). The app must not look like generic AI output: no gradients, no glows, no blurred shadows, no translucent cards, no violet, no emoji as chrome icons (emoji only inside content).

## Setup
```bash
export PATH=/opt/sdk/flutter/bin:$PATH CI=true
flutter pub get
mkdir -p node_modules && ln -sfn $(npm root -g)/playwright node_modules/playwright   # for tool/shot.mjs
```

## Read first
- `lib/core/theme.dart` (colour, spacing, motion tokens, text styles via `context.text`)
- `lib/core/widgets.dart` (AppScaffold, Panel, ChunkyButton, StatPill, FatProgress, Badge3D, and the motion and 3D pieces: Pressable, Tilt3D, PopIn, CountUp, Coin3D, OutlinedText). `pieceDecoration()` in theme.dart is the one surface style.
- `lib/core/sfx.dart`: call `Sound.play(Sfx.coin)` on meaningful events (tap, correct, wrong, coin, powerup, levelUp, crash, jump, drop, perfect, merge, swipe, win, lose, tick). `Pressable` and `ChunkyButton` already play the tap sound.
- `lib/core/profile.dart` (player state: `profileProvider`, rewards, streak, story and lesson progress)
- `lib/core/content_repo.dart`, `lib/domain/entities/*.dart` (content model and question payload shapes)
- `lib/features/games/_shared/*.dart` (ArcadeGame base, GameHostScreen, registry)
- `lib/core/router.dart` (routes and what they return)

## Rules
1. Edit only the files your task names. Do not edit `pubspec.yaml`, `lib/core/`, `lib/domain/` or another feature's folder. If you truly need a change there, do not make it: say so in your report.
2. No new dependencies. Flame, Riverpod, go_router, shared_preferences and http are installed.
3. Use the design tokens and shared widgets. No raw hex colours in app screens, no new fonts. Visuals are drawn in code (Canvas, CustomPainter, transforms). No image assets, no new audio files. App screens follow DESIGN.md strictly. Game canvases paint their own world and may use gradients inside the canvas, but pickups, tiles and UI-like pieces should share the outlined, chunky look where it suits the game. Respect `context.reduceMotion`.
4. Layout must work from 360x640 to tablet width, with text scale up to 1.3. Tap targets at least 48px. Add `Semantics` labels to custom-painted controls.
5. Smallest code that fully does the job. No speculative options or abstractions. Comment only the non-obvious why.
6. Content rules: education only, never investment advice. No real scheme, fund house or stock names. No promised returns. Numbers are illustrative and say so. Use rupees (₹).
7. Before you finish:
   - `dart format lib test` (page width 120 is configured)
   - `flutter analyze --no-fatal-infos` shows no errors or warnings (the `deprecated_member_use` info about `flutter/material.dart` is known, ignore it)
   - `flutter test` passes, including at least one new test for your logic
   - Visual check: `flutter build web --no-web-resources-cdn && node tool/shot.mjs <out-dir> '<route>' [steps]`, then look at the PNGs with the Read tool and fix what looks wrong. Routes use a hash: `/#/play/runner`, `/#/lesson/mf-basics-1`, `/#/story`. Steps: `x,y` taps, `swipe:x1,y1,x2,y2`, `wait:ms` (viewport is 390x844).
8. Commit your work on your current branch (do not push, do not touch `main`). End the commit message with:
   ```
   Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>
   Claude-Session: https://claude.ai/code/session_017ZwEWa73h2aZwbiYtmSB7C
   ```
9. Final report, 10 lines max: branch name, commit hash, what works, what you verified visually, anything skipped or broken, any change you need outside your folder.

## Fixed ids
Lessons (module-lesson): `mf-basics-1..4`, `fund-types-1..4`, `sip-power-1..4`.
- mf-basics: 1 Saving vs investing, 2 What is a mutual fund, 3 NAV and units, 4 Who runs your fund and what it costs
- fund-types: 1 Equity funds, 2 Debt funds, 3 Hybrid and index funds, 4 Risk and matching funds to goals
- sip-power: 1 What is a SIP, 2 Rupee cost averaging, 3 Power of compounding, 4 Staying invested through ups and downs

Games: `runner` (Bull Run), `stack` (Sky Stack), `merge` (Coin Merge), `breaker` (Brick Bank), `flap` (Candle Hop), `slice` (Coin Slash).

Arcade rule: the host never pauses a run for a question. `requestBoost()` makes the host show a small quiz chip over the bottom ~170px of the screen while your game keeps running, so keep critical gameplay readable when that area is covered. Death goes straight to the host's results screen.
Score scales: runner = metres run (about 10 per second), stack = blocks placed, merge = sum of merged values (2048 style).
