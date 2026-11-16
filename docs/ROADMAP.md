# Investor Education Game: Build Roadmap

A Flutter app with three modes (Pure Game, Story Mode, Pure Edu), Firebase backend, 2D mini-games in Flame, and an optional 3D title embedded later.

---

## 0. Guiding Principles

1. **Content is the bottleneck, not code.** Plan content production in parallel with engineering from week 1.
2. **Validate cheap things first.** Ship the education loop before the game loop, and the game loop before 3D.
3. **One engine-agnostic contract.** Every mini-game implements the same `MiniGame` interface, so Flame or Unity games plug in identically.
4. **One economy.** Coins, XP, Knowledge Points and inventory are shared across all modes and games.
5. **Education is not advice.** Compliance review is a gate, not an afterthought.
6. **Measure before expanding.** Each phase ends with a go/no-go on retention data.

---

## 1. Team and Roles

| Role | Phase involvement |
|---|---|
| Product owner / game designer | All phases |
| Flutter engineer(s) (2) | All phases |
| Backend / Firebase engineer (0.5–1) | Phases 0–2, 4 |
| UI/UX designer | Phases 0–4 |
| 2D artist / animator | Phases 2–5 |
| Finance subject-matter expert (SME) | All phases, content review |
| Content writer / instructional designer | All phases |
| QA | Phases 2 onward |
| Compliance / legal reviewer | Phases 0, 4, 5 |
| 3D artist + Unity dev (optional) | Phase 6 only |

---

## 2. Phase Overview

| Phase | Weeks | Goal | Exit criteria |
|---|---|---|---|
| **0. Foundations** | 1–2 | Align on content, design, tech skeleton | Topic map, wireframes, repo + CI + Firebase project live |
| **1. Edu Core (Pure Edu)** | 3–6 | Working learn-and-quiz app | 10 lessons + 100 questions playable end to end, auth works, streaks/XP work |
| **2. Game Core (Pure Game)** | 7–11 | Game platform plus first mini-games | 3 games shipped behind the `MiniGame` contract, powerup flow works |
| **3. Story Mode** | 12–16 | Narrative layer joining lessons and games | Story chapters 1–4 playable, unlock rules working |
| **4. Retention and Polish** | 17–20 | Daily loops, social, live-ops tooling | Daily challenge, leagues, notifications, remaining games, localisation |
| **5. Beta and Launch** | 21–24 | Hardening and store release | Closed beta passed, compliance sign-off, store approval |
| **6. 3D Spike (optional)** | 25–30 | Prove or kill a Unity-embedded 3D game | Go/no-go based on retention and device performance |

Timeline assumes a team of ~6–8. Compress or stretch as headcount changes.

---

## 3. Phase 0: Foundations (Weeks 1–2)

### Product and content
- [ ] Define target audience (age, region, language, prior knowledge).
- [ ] Build the **topic map**: modules, lessons and learning objectives, ordered by difficulty.
  - Suggested spine: saving vs investing, what a mutual fund is, fund types, SIP and compounding, costs (NAV, expense ratio, exit load), risk and volatility, goals and allocation, taxation basics.
- [ ] Define question types and a schema for each (MCQ, true/false, myth/fact, match, order, numeric slider, scenario, spot-the-red-flag).
- [ ] Draft the **content style guide** (tone, reading level, max card length, explanation format).
- [ ] Pick the main story line (recommended: "From Pocket Money to Portfolio") and outline 8 chapters.
- [ ] Compliance brief: disclaimer language, rules on naming real schemes, what is illustrative vs real data.

### Design
- [ ] Brand, art direction and UI kit (colours, typography, component library).
- [ ] Wireframes for the home hub, mode selector, lesson player, quiz screen, game host, profile, shop.
- [ ] Define the **powerup system** (types, rarity, how a question awards each).
- [ ] Define the economy: currencies, earn/spend rates, sinks.

### Engineering
- [ ] Repo, branching strategy, lint rules, CI (build, test, analyze) on every PR.
- [ ] Flutter project with feature-first structure (see Section 6).
- [ ] State management (Riverpod), routing (go_router), DI.
- [ ] Firebase project: dev and prod environments, Auth, Firestore, Remote Config, Analytics, Crashlytics.
- [ ] Define Firestore schema v1 and draft security rules.
- [ ] Localisation scaffolding (ARB files) from day one.

**Deliverables:** topic map, wireframes, UI kit, economy doc, empty-but-running app with CI.

---

## 4. Phase 1: Edu Core / Pure Edu (Weeks 3–6)

Ship this first. It is the cheapest way to validate that the content is good and that users come back.

### Features
- [ ] Auth: Google, phone OTP and guest (anonymous, with later account linking).
- [ ] Onboarding and level placement quiz.
- [ ] Lesson player: swipeable cards (text, image, short animation), progress bar.
- [ ] **Quiz engine** with a renderer per question type (start with MCQ, true/false, myth/fact, match).
- [ ] Explanations after every answer ("why").
- [ ] XP, levels, daily streak, basic badges.
- [ ] Profile and progress screen.
- [ ] Offline support: bundled starter content plus delta sync.

### Backend and tooling
- [ ] Firestore collections: `users`, `content/modules`, `content/lessons`, `content/questions`, `progress`.
- [ ] **Content admin tool** (web): author, preview, version and publish lessons and questions without an app release.
- [ ] Cloud Functions: XP/streak validation, streak reset job.
- [ ] Analytics events: lesson_start/complete, question_answered (correct, time), drop-off points.

### Content (in parallel)
- [ ] 10 lessons and 100+ reviewed questions.
- [ ] SME review workflow: draft, SME review, compliance review, publish.

### Exit criteria
- A new user can sign up, finish a module and keep a streak.
- Day-1 and day-7 retention are measured, and lesson completion rate is above the agreed target.

---

## 5. Phase 2: Game Core / Pure Game (Weeks 7–11)

### Platform pieces (build before games)
- [ ] **`MiniGame` contract**: `init(config)`, `start()`, `pause()`, `applyPowerup(type)`, `requestQuestion()`, returns `GameResult`.
- [ ] **`GameHost`**: Flutter widget that runs a Flame game and overlays Flutter UI (pause, HUD, question popup).
- [ ] **Powerup/question interrupt in Flutter**: the game pauses, a question overlay appears and the result maps to a powerup.
- [ ] Shared economy: coins, gems, XP, inventory, loadout selection before a run.
- [ ] `GameRegistry` (Firestore plus Remote Config): per-game config, enable/disable flags, difficulty curves.
- [ ] Cloud Function that validates a `GameResult` (plausible score and time) before awarding rewards.
- [ ] Shop v1: cosmetics and consumables.

### First three mini-games (different input styles)
1. **Endless Runner** (swipe lanes): core loop, obstacles, coins, powerups. Reskinned with market theming but fun with no finance knowledge.
2. **Stack / Tower Builder** (tap timing): one-thumb, instant restart, perfect-streak combo.
3. **Merge game** (2048-style): coins merge into bars and vaults.

### Game feel (do not skip)
- [ ] Juice: particles, screen shake, haptics, SFX and music, 60 fps target.
- [ ] Instant restart, short sessions (30–90 s), clear failure feedback.

### Exit criteria
- All three games run at a stable frame rate on a low-end Android device.
- A player can pick a loadout, play, answer a powerup question, earn rewards, and see them in their inventory.
- Leaderboards (basic, global) work.

---

## 6. Phase 3: Story Mode (Weeks 12–16)

### Systems
- [ ] **Story engine**: chapters as a graph of nodes (cutscene/dialogue, lesson, game, boss/scenario, reward).
- [ ] Unlock rules: knowledge gates progress (e.g. pass the lesson quiz to open the next game level).
- [ ] Hub map screen (the "Market City" / chapter map) with progress and replayable districts.
- [ ] Dialogue and cutscene system (lightweight: illustrated panels plus text, with optional voice later).
- [ ] Narrative state saved per user, with the ability to resume.
- [ ] Bridge to games: story passes a `config` (theme, difficulty, goal) into a `MiniGame`.

### Content
- [ ] Chapters 1–4 scripted, illustrated and playable (Salary Day, Meet the Pool, Fund Zoo, Magic of SIP).
- [ ] Scenario questions ("market falls 15%, what do you do?") as chapter bosses.
- [ ] Add the remaining question types: order, numeric slider, scenario, spot-the-red-flag.

### Match-3 meta layer (recommended here)
- [ ] Match-3 game with a level map that doubles as story progression.

### Exit criteria
- A new user can play chapters 1–4 start to finish.
- Story completion rate and the lesson to game transition drop-off are measured and acceptable.

---

## 7. Phase 4: Retention and Polish (Weeks 17–20)

- [ ] **Daily loop**: daily challenge (Wordle-style jargon puzzle plus a scenario question), daily quests, login rewards.
- [ ] **Streak mechanics**: streak saver powerup, streak freeze.
- [ ] **Social**: friend leagues, weekly leaderboards, shareable result cards.
- [ ] **Notifications** (FCM): streak reminders, league updates. Throttled and opt-in aware.
- [ ] More games: Brick Breaker, Myth Buster (swipe), Jargon Wordle, plus an idle/tycoon game for return visits.
- [ ] Chapters 5–8 completed.
- [ ] Hindi (and other regional languages if in scope) localisation pass.
- [ ] Accessibility: font scaling, contrast, colour-blind-safe palettes, screen-reader labels, reduced motion.
- [ ] Economy balancing via Remote Config and A/B tests.
- [ ] Healthy-play guardrails: session-length nudges, no dark patterns.
- [ ] Performance pass: startup time, memory, app size, battery.

---

## 8. Phase 5: Beta and Launch (Weeks 21–24)

- [ ] **Closed beta** (200–500 users): crash-free rate, retention, tutorial drop-off, economy health.
- [ ] Content QA sweep: factual accuracy, typos, broken explanations.
- [ ] **Compliance sign-off**: disclaimers, no scheme recommendations, privacy policy and consent, age gate (DPDP Act if India).
- [ ] Security review: Firestore rules, Cloud Functions abuse cases, reward-farming and score-spoofing tests.
- [ ] Load and cost test: Firestore read/write patterns, caching, budget alerts.
- [ ] Store listings: screenshots, descriptions, privacy labels, age rating.
- [ ] Staged rollout (e.g. 5%, 20%, 100%) with crash and retention monitoring.
- [ ] Support channel and feedback loop in-app.

---

## 9. Phase 6: Optional 3D Spike (Weeks 25–30)

Only start if Phase 5 retention data justifies it and the team has (or can hire) Unity and 3D art skills.

### Spike 1: feasibility (2 weeks)
- [ ] Embed Unity in Flutter with `flutter_unity_widget`.
- [ ] Build a throwaway 3D scene and test on a ₹8–10k Android device and a mid-range iPhone.
- [ ] Measure: app size delta, cold start, memory, frame rate, battery, crash rate.
- [ ] Test the bridge: Flutter sends `{userId, loadout, difficulty}`, Unity returns `{score, coins, completed}`.
- [ ] Test the pause/question-overlay flow with Unity running.

### Go/no-go
- **Go** if the performance targets are met and the bridge is stable.
- **No-go** falls back to a 2.5D look in Flame (isometric or pseudo-3D runner) or keeps 3D only for reward-screen flair via native Flutter 3D packages.

### If go (4 weeks)
- [ ] Build one 3D game (3D endless runner as a showcase).
- [ ] Ship it as a downloadable asset module (Play Asset Delivery / on-demand resources) so the base install stays small.
- [ ] Gate it by device tier via Remote Config (`minDeviceTier`).
- [ ] Implement it behind `UnityMiniGame : MiniGame` so nothing else in the app changes.

---

## 10. Architecture Reference

### Client structure
```
lib/
  core/            theme, routing, DI, errors, analytics wrapper
  data/            repositories, Firebase datasources, local cache, DTOs
  domain/          entities, use-cases (pure Dart, unit-testable)
  features/
    auth/
    home_hub/      mode selector, daily challenge
    content/       lesson player, quiz engine (renderer per question type)
    story/         chapter map, narrative engine, cutscenes
    games/
      _shared/     GameHost, MiniGame contract, powerups, scoring
      runner/  stack/  merge/  match3/  brick/  wordle/ ...
    progress/      XP, streaks, badges, inventory
    shop/
    leaderboard/
    settings/
```

### Firestore model (v1)
```
users/{uid}                  profile, level, xp, streak, prefs
users/{uid}/progress/{id}    lesson/module completion, scores
users/{uid}/inventory/{id}   powerups, cosmetics
content/modules/{id}         title, topic, order
content/lessons/{id}         cards, moduleId, version
content/questions/{id}       type, payload, topic, difficulty, explanation, status
story/chapters/{id}          nodes, lessonIds, gameId, unlock rules
games/{id}                   engine (flame|unity), config, minDeviceTier, version
leaderboards/{period}/entries
```

### Backend responsibilities (Cloud Functions)
- Validate XP, score and reward submissions.
- Streak rollover and reset jobs.
- Leaderboard and league rollover.
- Notification scheduling.

---

## 11. Quality Strategy

| Layer | Approach |
|---|---|
| Unit tests | Domain use-cases, economy math, question scoring |
| Widget tests | Quiz renderers, lesson player |
| Integration tests | Sign-up to lesson to game to reward flow |
| Game testing | Frame-rate budget on low-end devices, input latency, soak tests |
| Content QA | SME review, compliance review, automated lint (length, missing explanations) |
| Security | Firestore rules tests, Cloud Function abuse cases |
| Analytics QA | Event schema checks before each release |

CI gates: format, analyze, tests, build, size budget.

---

## 12. Key Metrics

| Area | Metrics |
|---|---|
| Acquisition and onboarding | Install to sign-up rate, tutorial completion |
| Engagement | DAU/MAU, session length, sessions per day |
| Retention | D1, D7, D30 |
| Learning | Lesson completion, quiz accuracy, improvement over time, repeat-wrong topics |
| Game | Runs per session, powerup question accept/answer rates, game-over to retry rate |
| Economy | Currency earn/spend balance, shop conversion |
| Health | Crash-free users, ANR rate, cold-start time, app size |

Decision rules (set targets in Phase 0): if D7 retention or lesson completion is below target after Phase 1, fix content and onboarding before building more games.

---

## 13. Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Not enough quality content | Hire writers and SMEs early, author tool in Phase 1, content pipeline with review gates |
| Education feels bolted onto the games | Playtest the question-interrupt moment, reward with powerups, keep games fun with zero knowledge |
| Mini-game scope creep | Ship 3–5 polished games, add one new game per live-ops cycle |
| Low-end device performance | Test on budget phones from Phase 2, frame and size budgets in CI |
| Unity bridge instability | Treat 3D as an optional spike, abstract behind `MiniGame`, pin versions |
| Compliance issues | Review at Phases 0, 4 and 5, avoid naming schemes, label illustrative numbers |
| Reward farming and cheating | Server-side validation, rate limits, anomaly detection |
| Firebase cost growth | Cache aggressively, batch writes, budget alerts, review read patterns |
| Localisation retrofit | ARB files and string externalisation from day one |

---

## 14. Immediate Next Steps (First 2 Weeks)

1. Confirm target market, languages, and platform priorities.
2. Appoint the finance SME and the compliance reviewer.
3. Produce the topic map and the first 20 questions as a content proof of concept.
4. Finalise wireframes for the hub, lesson player and quiz screen.
5. Stand up the repo, CI and the Firebase dev and prod projects.
6. Define the `MiniGame` interface and the `GameResult` schema on paper.
7. Agree the success metrics and go/no-go thresholds for each phase.
