# 5-Hour Execution Plan

Goal: a solid, good-looking, testable app at the end of every stage. Each stage ends with a git tag. A tag triggers CI, which publishes a GitHub Release with an installable APK.

## How the work is split

| Who | Does |
|---|---|
| Fable (lead) | Architecture, design system, interfaces between features, integration, review of every merge, release tagging |
| Opus agents | Hard parts: Flame games, story engine, sync logic |
| Sonnet agents | Feature screens, quiz renderers, tests |
| Haiku agents | Content drafts (lessons, questions as JSON), boilerplate, lint fixes |

Rules for parallel work:
- The lead writes interfaces and the design system first. Agents build against them.
- Each agent owns one folder under `lib/features/` and works in its own git worktree, so agents do not collide.
- Nothing merges to `main` unless `flutter analyze` and `flutter test` pass and the lead has looked at a web screenshot.

## How each stage is tested

1. Automated: analyze, unit and widget tests in CI.
2. Lead: web build driven in headless Chromium, with screenshots.
3. You: install the APK from the GitHub Release on your Android phone.

## Stages

### Stage 0: Foundation, tag `v0.1.0` (0:00 to 0:25)
- Design system: colour tokens, typography, spacing, motion, light and dark themes, core components (buttons, cards, progress, chips, sheets).
- App shell: hub screen, mode selection, bottom navigation, routing.
- Local persistence for the player profile (works with no network and no login).
- Release pipeline: tag push builds an APK and attaches it to a GitHub Release.
- **Test:** install the APK. Hub opens, three modes are visible, theme switches, navigation works.

### Stage 1: Pure Edu, tag `v0.2.0` (0:25 to 1:25)
- Lesson player: swipeable cards with progress.
- Quiz engine with renderers for MCQ, true/false, myth/fact (swipe) and match-the-pair. Explanation after every answer.
- XP, levels, daily streak, module completion.
- Content bundled in the app: 3 modules, about 12 lessons, about 60 questions (what a mutual fund is, fund types, SIP and compounding).
- **Test:** finish a module end to end, earn XP, close and reopen the app, progress is kept.

### Stage 2: Pure Game, tag `v0.3.0` (1:25 to 2:35)
- `GameHost`: runs any `MiniGame`, pause, HUD, results screen.
- Question-for-a-powerup overlay shared by all games.
- Three games, built in parallel: Endless Runner (swipe), Stack (tap timing), Merge (2048-style).
- Coins, powerup inventory, high scores.
- **Test:** play all three, answer a boost question mid-run, see the powerup apply, coins land in the profile.

### Stage 3: Story Mode, tag `v0.4.0` (2:35 to 3:30)
- Chapter map with locked and unlocked nodes.
- Story engine: dialogue, lesson, game and scenario nodes defined as data.
- Chapters 1 to 3 of "From Pocket Money to Portfolio", each ending in a scenario decision.
- **Test:** play chapters 1 to 3 in order. A locked chapter opens only after the previous one is passed.

### Stage 4: Firebase, tag `v0.5.0` (3:30 to 4:15)
- Anonymous sign-in on first launch, Google sign-in to keep progress across devices.
- Profile and progress sync to Firestore. Local data stays the source when offline.
- Content loads from Firestore with the bundled content as fallback, plus a seeding script.
- **Needs from you:** a fresh access token (about 5 minutes) when this stage starts. If it is not available, this stage moves to the end and Stage 5 runs first.
- **Test:** sign in on the phone, play, see the user document in the Firebase console.

### Stage 5: Polish, tag `v1.0.0-beta` (4:15 to 5:00)
- Daily challenge, micro-animations, haptics, empty and error states.
- Accessibility pass: text scaling, contrast, screen-reader labels, reduced motion.
- Full-repo audit and fixes, performance pass, README with screenshots.
- **Test:** full run through all three modes on the phone.

## Out of scope for these 5 hours

- 3D or Unity work, iOS builds, store submission.
- Cloud Functions for server-side score validation (needs the paid Firebase plan). Until then rewards are stored locally and synced, which is fine for a beta but not cheat-proof.
- Custom illustrations, music and sound. Visuals are drawn in code (shapes, gradients, particles).
- Hindi and other languages. Strings are kept ready for translation.
- Finance content is a draft and needs review by a subject-matter expert and compliance before public release.

## Risks

| Risk | Handling |
|---|---|
| Times slip | Stages are ordered by value. Whatever is tagged is shippable, later stages shrink first. |
| No Android device here | Web build tests plus your APK check after each tag. |
| Parallel agents conflict | One folder per agent, interfaces fixed first, lead merges. |
| Access token expires hourly | Firebase work is grouped into one stage. |
