import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../core/utils/day_key.dart';
import '../engine/autocomplete_engine.dart';
import '../engine/badge_engine.dart';
import '../engine/streak_engine.dart';
import '../engine/xp_engine.dart';
import '../platforms/github_provider.dart';
import '../platforms/leetcode_provider.dart';
import '../platforms/platform_provider.dart';
import '../services/notification_service.dart';
import 'models.dart';

const _prefsKey = 'commit_state_v1';
const _uuid = Uuid();

final prefsProvider = Provider<SharedPreferences>((_) => throw UnimplementedError());
final clockProvider = Provider<DateTime Function()>((_) => DateTime.now);
final httpClientProvider = Provider<http.Client>((_) => http.Client());

final appProvider = NotifierProvider<AppNotifier, AppState>(AppNotifier.new);

final todayProvider = Provider<String>((ref) {
  ref.watch(appProvider); // re-evaluate when state changes (covers midnight rollovers on use)
  return dayKey(ref.read(clockProvider)());
});

class CommitResult {
  final int taskXp;
  final int bonus;
  final bool critical;
  final List<String> newBadges;
  final int streak;
  final int levelBefore;
  final int levelAfter;
  final bool stashEarned;
  final bool hotfixed;
  const CommitResult(this.taskXp, this.bonus, this.critical, this.newBadges, this.streak,
      this.levelBefore, this.levelAfter, this.stashEarned, {this.hotfixed = false});
}

class AppNotifier extends Notifier<AppState> {
  SharedPreferences get _prefs => ref.read(prefsProvider);
  String get _today => dayKey(ref.read(clockProvider)());

  @override
  AppState build() {
    final raw = _prefs.getString(_prefsKey);
    var s = AppState();
    if (raw != null) {
      try {
        s = AppState.decode(raw);
      } catch (_) {}
    }
    if (s.onboarded) s = applyStashIfNeeded(s, _today);
    return s;
  }

  void _set(AppState s) {
    state = s;
    _prefs.setString(_prefsKey, s.encode());
  }

  /// Re-plan tonight's single reminder from current state.
  Future<void> replanReminder() async {
    final s = state;
    if (!s.onboarded || !s.notifications) return;
    final today = _today;
    await NotificationService.instance.scheduleEvening(
      hour: s.reminderHour,
      streak: computeStreak(s, today).current,
      committedToday: s.commits.any((c) => c.day == today && !c.frozen),
    );
  }

  // ---- onboarding / settings ----
  void completeOnboarding({
    required String name,
    required String identity,
    required List<String> skills,
    String github = '',
    String leetcode = '',
  }) =>
      _set(state.copyWith(
        onboarded: true,
        name: name,
        identity: identity,
        focusSkills: skills,
        githubUser: github,
        leetcodeUser: leetcode,
      ));

  void updateSettings({
    String? name,
    String? identity,
    List<String>? focusSkills,
    String? themeMode,
    bool? notifications,
    int? reminderHour,
    String? githubUser,
    String? leetcodeUser,
  }) =>
      _set(state.copyWith(
        name: name,
        identity: identity,
        focusSkills: focusSkills,
        themeMode: themeMode,
        notifications: notifications,
        reminderHour: reminderHour,
        githubUser: githubUser,
        leetcodeUser: leetcodeUser,
      ));

  void scheduleRestDay(String day) {
    if (state.restDays.contains(day)) return;
    _set(state.copyWith(restDays: [...state.restDays, day]));
  }

  // ---- tasks ----
  Task addTask({
    required String title,
    required TaskType type,
    required String skill,
    int difficulty = 1,
    String fallback = '',
    AutoRule? rule,
    bool stageToday = true,
  }) {
    final t = Task(
      id: _uuid.v4(),
      title: title,
      type: type,
      skill: skill,
      difficulty: difficulty,
      fallback: fallback.isEmpty ? _defaultFallback(type, skill) : fallback,
      stagedFor: stageToday ? _today : null,
      rule: rule,
    );
    _set(state.copyWith(tasks: [...state.tasks, t]));
    return t;
  }

  String _defaultFallback(TaskType type, String skill) => switch (type) {
        TaskType.dsa => 'Read one $skill problem and sketch an approach',
        TaskType.project => 'Open the project and write the next step down',
        TaskType.learning => 'Read for 2 minutes about $skill',
        TaskType.hackathon => 'Jot down one idea for the theme',
        TaskType.openSource => 'Skim one open issue',
      };

  void _updateTask(String id, Task Function(Task) f) =>
      _set(state.copyWith(tasks: [for (final t in state.tasks) t.id == id ? f(t) : t]));

  void stage(String id) => _updateTask(id, (t) => t.copyWith(stagedFor: _today));
  void unstage(String id) => _updateTask(id, (t) => t.copyWith(clearStaged: true));
  void toggleDone(String id, {bool fallback = false}) => _updateTask(id, (t) {
        if (t.done) return t.copyWith(done: false, doneViaFallback: false, auto: false, clearDone: true);
        return t.copyWith(done: true, doneViaFallback: fallback, doneDay: _today, stagedFor: t.stagedFor ?? _today);
      });
  void deleteTask(String id) => _set(state.copyWith(tasks: state.tasks.where((t) => t.id != id).toList()));

  void acceptSuggestion({
    required String title,
    required String skill,
    required TaskType type,
    required int difficulty,
    required String fallback,
    AutoRule? rule,
  }) =>
      addTask(title: title, type: type, skill: skill, difficulty: difficulty, fallback: fallback, rule: rule);

  void dismissSuggestion(String title) =>
      _set(state.copyWith(dismissedSuggestions: [...state.dismissedSuggestions, '$_today|$title']));

  // ---- day commit ----
  bool get committedToday => state.commits.any((c) => c.day == _today && !c.frozen);

  /// Commit the day: award skill XP, bonus, badges, stash. Idempotent per day.
  CommitResult? commitDay(String message) {
    final today = _today;
    if (committedToday) return null;
    final done = state.tasks.where((t) => t.done && t.doneDay == today).toList();
    final levelBefore = levelFor(state.totalXp).level;
    final skillXp = Map<String, int>.from(state.skillXp);
    var taskXp = 0;
    for (final t in done) {
      skillXp[t.skill] = (skillXp[t.skill] ?? 0) + t.xp;
      taskXp += t.xp;
    }
    final crit = done.isNotEmpty && isCriticalDay(today);
    final bonus = commitBonus(today, done.length);
    final commit = DayCommit(
      day: today,
      message: message.trim().isEmpty ? 'shipped ${done.length} change${done.length == 1 ? '' : 's'}' : message.trim(),
      xp: taskXp + bonus,
      bonus: bonus,
      tasks: done.length,
      critical: crit,
    );
    final hour = ref.read(clockProvider)().hour;
    final hotfix = done.length >= 2 && hotfixAvailable(state, today);
    var s = state.copyWith(
      skillXp: skillXp,
      commits: [...state.commits.where((c) => c.day != today), commit],
      badges: hour >= 23 && !state.badges.contains('night') ? [...state.badges, 'night'] : null,
    );
    if (hotfix) s = applyHotfix(s, today);
    final streak = computeStreak(s, today).current;
    final before = s.stash;
    s = awardStash(s, streak);
    final earnedBadges = newBadges(s, today);
    s = s.copyWith(badges: [...s.badges, ...earnedBadges]);
    _set(s);
    replanReminder();
    return CommitResult(taskXp, bonus, crit, earnedBadges, streak, levelBefore,
        levelFor(s.totalXp).level, s.stash > before, hotfixed: hotfix);
  }

  // ---- wallet ----
  void addWallet(WalletItem item) {
    final w = WalletItem(
      id: _uuid.v4(),
      kind: item.kind,
      title: item.title,
      body: item.body,
      tags: item.tags,
      status: item.status,
      extra: item.extra,
    );
    _set(state.copyWith(wallet: [w, ...state.wallet]));
    _awardBadgesQuiet();
  }

  void togglePin(String id) => _set(state.copyWith(
      wallet: [for (final w in state.wallet) w.id == id ? w.copyWith(pinned: !w.pinned) : w]));
  void setStatus(String id, String status) => _set(state.copyWith(
      wallet: [for (final w in state.wallet) w.id == id ? w.copyWith(status: status) : w]));
  void deleteWallet(String id) => _set(state.copyWith(wallet: state.wallet.where((w) => w.id != id).toList()));

  void _awardBadgesQuiet() {
    final nb = newBadges(state, _today);
    if (nb.isNotEmpty) _set(state.copyWith(badges: [...state.badges, ...nb]));
  }

  // ---- platform sync ----
  Future<void> sync({bool force = false}) async {
    final client = ref.read(httpClientProvider);
    final clock = ref.read(clockProvider);
    final jobs = <(PlatformProvider, String)>[
      if (state.githubUser.isNotEmpty) (GithubProvider(client, now: clock), state.githubUser),
      if (state.leetcodeUser.isNotEmpty) (LeetcodeProvider(client, now: clock), state.leetcodeUser),
    ];
    await Future.wait(jobs.map((j) async {
      final (p, user) = j;
      final cached = state.snapshots[p.id];
      if (!force && cached != null && cached.username == user &&
          clock().difference(cached.fetchedAt).inMinutes < 30) {
        return;
      }
      try {
        final snap = await p.fetch(user);
        _set(state.copyWith(
          snapshots: {...state.snapshots, p.id: snap},
          syncErrors: {...state.syncErrors}..remove(p.id),
        ));
      } on PlatformException catch (e) {
        _set(state.copyWith(syncErrors: {...state.syncErrors, p.id: e.message}));
      } catch (_) {
        _set(state.copyWith(syncErrors: {...state.syncErrors, p.id: 'Could not reach ${p.id}'}));
      }
    }));
    _autoComplete();
  }

  void _autoComplete() {
    final today = _today;
    final hits = satisfiedTasks(state, today);
    if (hits.isEmpty) return;
    final ids = hits.map((t) => t.id).toSet();
    _set(state.copyWith(tasks: [
      for (final t in state.tasks)
        ids.contains(t.id) ? t.copyWith(done: true, auto: true, doneDay: today) : t,
    ]));
    _awardBadgesQuiet();
  }

  /// Validate a username before onboarding finishes.
  Future<PlatformSnapshot> probe(String platform, String user) async {
    final client = ref.read(httpClientProvider);
    final clock = ref.read(clockProvider);
    final p = platform == 'github' ? GithubProvider(client, now: clock) : LeetcodeProvider(client, now: clock);
    return p.fetch(user);
  }

  void cacheSnapshot(PlatformSnapshot snap) =>
      _set(state.copyWith(snapshots: {...state.snapshots, snap.platform: snap}));

  /// Logs a finished focus session and turns it into skill XP (1 xp per 2.5 min).
  int logFocus(String skill, int minutes) {
    if (minutes <= 0) return 0;
    final xp = (minutes * 0.4).round().clamp(1, 1000);
    final today = _today;
    _set(state.copyWith(
      skillXp: {...state.skillXp, skill: (state.skillXp[skill] ?? 0) + xp},
      focusMinutes: {...state.focusMinutes, skill: (state.focusMinutes[skill] ?? 0) + minutes},
      focusByDay: {...state.focusByDay, today: (state.focusByDay[today] ?? 0) + minutes},
    ));
    return xp;
  }

  void resetAll() => _set(AppState());
}
