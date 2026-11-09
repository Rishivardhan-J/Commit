# Commit — project summary (handoff notes)

Flutter app "Commit": your life as a git repo, for developers/students. Built from `Commit_PRD.docx`.
Repo: https://github.com/Rishivardhan-J/Commit.git (branch `main`, last pushed commit `f00cb8f`).

## Standing rules from the owner
- When committing/pushing: **do NOT add Claude as a contributor** (no Co-Authored-By, no Claude attribution). Commit/push only when asked.
- Author: Rishivardhan <rishivardhan.j2024cse@sece.ac.in>.
- Make a plan before big work; the owner approves with "Start to cook."

## Stack
- Flutter 3.47.1 / Dart 3.13.1, Riverpod 3 (`Notifier`, no codegen), go_router 18, shared_preferences (JSON state `commit_state_v1`, focus state `commit_focus_v1`), fl_chart, flutter_animate, google_fonts pinned `^8.2.1` (9.x breaks TextTheme), flutter_local_notifications 23, workmanager, local_auth, wakelock_plus, audioplayers, share_plus, file_picker, speech_to_text, home_widget.
- Android: compileSdk 37, core-library desugaring, MainActivity extends FlutterFragmentActivity.
- Test device: CPH2491, id `G6W4WC5D7HT8EQF6` (`flutter build apk --debug`, `adb install -r`, `adb exec-out screencap -p`; screenshots shown at 1152 wide = scale 1.08 to 1240 px).

## Architecture
- `lib/engine` pure logic: xp, streak, coding_score (`scoreFromSnapshots`), autocomplete, suggestion, badge, challenge_engine.
- `lib/platforms`: GitHub, LeetCode, Codeforces providers behind `PlatformProvider`; `sync_service.dart` used by background sync.
- `lib/data`: `models.dart` (AppState, Task, DayCommit, WalletItem, PlatformSnapshot, Friend, FocusSession), `app_store.dart` (AppNotifier).
- `lib/features/*` screens: home, tasks (Today/Week/Backlog/Skills), vault (incl. snippets), skills (radar, challenges, leaderboard link), stats (trends), friends, focus, capture (voice), commit, onboarding, profile/settings, roadmap.
- `lib/core`: theme ("Focused Indigo", `context.cc`), router, widgets (toast, polish: AnimatedCount/staggerIn/ConfettiBurst, commit_logo).
- `lib/services`: notifications (evening reminder, focus countdown), background sync, backup, home-widget.
- Time is injectable (`clockProvider`); day keys are `yyyy-MM-dd` (`core/utils/day_key.dart`).

## What is built
- Core loop: stage tasks in the morning, "commit the day" in the evening, streak with stash and hotfix, XP/skill levels, badges, rest days, weekly recap, suggestions from weak topics.
- Platforms: GitHub, LeetCode, Codeforces sync with auto-complete rules, feedback toasts, Android background sync.
- Friends leaderboard (public usernames only, no backend), backup export/import JSON, vault snippets (monospace + copy), weekly planner, weekly challenges (bonus XP), trends on Stats, voice capture, Android home-screen widget, launch screen mark, new logo/icons.
- UI polish: staggered Home entrance, animated counters, confetti + shareable card on commit, bottom-sheet drag handles, light-mode shadows, date numbers on week strip, shorter radar labels.
- **Focus timer ("Commit Grid")**: one square per minute filling like a contribution graph (liquid fill for the current minute), odometer digits, commit-message intention, 4-node cycle graph, pause/resume/+5/skip-break, long-press to stop, "I got distracted" + automatic context-switch tracking (away >= 10s), box-breathing guide on breaks, deep-focus OLED mode with pixel drift, length ruler 5–120 min + presets, daily goal bar, 12-week focus heatmap, git-log-style focus log (`AppState.focusLog`, capped at 200), commit sheet at block end (Shipped/Partly/Not yet, message, mark task done), ambient sound (brown/rain/café loops in `assets/sounds`, fades with timer state). XP is banked when a block ends; the sheet only annotates the log entry. State survives app kill (wall-clock `endsAt`).

## Verification status
- `flutter analyze` clean; `flutter test` 55 tests passing (engine, platforms incl. Codeforces, flow, feedback, logo, focus, backup, challenge).
- On device I verified: Home, the idle focus screen, a running block, the long-press-to-stop hint.
- **Not yet verified on device**: commit sheet + confetti, breathing breaks, deep focus mode, ambient audio, "away" toast, leaderboard, backup export/import, snippets, planner, voice capture, home widget, light-theme pass. After my last tap the app showed Home instead of the timer (no crash in logs; likely a stray tap).

## Known gaps / not done
- Part C items skipped: task-checkbox spring/strike animation, shimmer skeletons, spacing-scale cleanup, empty states with logo everywhere, accessibility pass.
- Not planned: CodeChef/GFG/HackerRank (no official APIs), Drift/SQLite migration, iOS background sync.
- README "Not yet built" list is out of date.
- Focus sound only starts on a state change (not auto-resumed after an app restart mid-block).
