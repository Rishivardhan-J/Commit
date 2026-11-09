# Commit — Commit code. Commit to goals.

A local-first Flutter app that turns your day into a git commit: stage 1–3 skill-tagged tasks in the
morning, let GitHub/LeetCode activity tick them off ("CI passed"), and commit the day in the evening.

## Run
```
flutter pub get
flutter test
flutter run            # device/emulator
```

## Design: "your life as a repo"
| Git idea | In the app | Psychology |
|---|---|---|
| staging area | pick 1–3 tasks each morning | choice limiting, implementation intentions |
| uncommitted changes | "N uncommitted changes" chip | Zeigarnik effect |
| git commit | evening ceremony with message, XP, critical (2×) commits | peak-end, variable reward |
| git stash | streak freeze, earned per 7-day streak (max 2), auto-applied | loss aversion without collapse |
| minimum viable commit | hold a task for its 2-minute version (half XP, streak safe) | Tiny Habits |
| PR from future you | weak-topic suggestions: Merge / Close | autonomy |
| `you v2.4` | level.skills-levelled version string | identity, goal gradient |
| release notes | Monday recap | fresh-start effect |

Guardrails: no guilt copy, at most one reminder a day, planned rest days keep the streak.

## Layout
`lib/engine` pure logic (XP, streak, score, suggestions, badges) · `lib/platforms` GitHub + LeetCode
providers (isolated, cached) · `lib/data` models + Riverpod store persisted via shared_preferences ·
`lib/features` screens.

## Also built
Focus (Pomodoro) timer that turns minutes into skill XP, goal roadmaps (placement, web, ML, GSoC),
hotfix streak repair, a scheduled evening reminder (re-planned on each open/commit), Android background sync.

## Not yet built
Cloud sync/auth, friends & leaderboards, home-screen widgets, voice capture, more platforms
(Codeforces, CodeChef…), Drift/SQLite storage (currently JSON in shared_preferences), iOS background sync.
LeetCode uses an unofficial endpoint and may break; failures fall back to cached data.
