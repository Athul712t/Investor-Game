# Investor Game

Investor-education app (mutual funds focus) with three modes: Pure Game, Story Mode, Pure Edu.
Flutter + Flame + Firebase. See [docs/ROADMAP.md](docs/ROADMAP.md).

## Setup status
- [x] Flutter scaffold, `MiniGame` contract, `QuestionEngine`, CI (test + debug APK)
- [x] Firestore rules and `firebase.json` (project `investor-game-dev`), not yet deployed
- [ ] `flutterfire configure` (needs Firebase login)
- [ ] Firebase Auth providers + Firestore database created in console

## Dev
```bash
flutter pub get && flutter test && flutter run -d chrome
```
