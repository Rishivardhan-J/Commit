import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../core/utils/day_key.dart';
import '../engine/autocomplete_engine.dart';
import '../engine/badge_engine.dart';
import '../engine/challenge_engine.dart';
import '../engine/streak_engine.dart';
import '../engine/xp_engine.dart';
import '../platforms/codeforces_provider.dart';
import '../platforms/github_provider.dart';
import '../platforms/leetcode_provider.dart';
import '../platforms/platform_provider.dart';
import '../services/notification_service.dart';
import '../services/widget_service.dart';
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

class PlatformResult {
  final String id, label, message;
  final bool ok;
  final bool skipped; // served from a fresh cache, no network call
  const PlatformResult(this.id, this.label, {required this.ok, required this.message, this.skipped = false});
}

class SyncReport {
  final List<PlatformResult> results;
  final List<Task> autoCompleted;
  const SyncReport(this.results, this.autoCompleted);
  bool get noAccounts => results.isEmpty;
  bool get anyFailed => results.any((r) => !r.ok);
  bool get allOk => results.isNotEmpty && !anyFailed;
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
    WidgetService.update(s, _today);
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
    String codeforces = '',
  }) =>
      _set(state.copyWith(
        onboarded: true,
        name: name,
        identity: identity,
        focusSkills: skills,
        githubUser: github,
        leetcodeUser: leetcode,
        codeforcesUser: codeforces,
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
    String? codeforcesUser,
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
        codeforcesUser: codeforcesUser,
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
  /// Plan a task for a specific (future) day; it surfaces in Today when that morning arrives.
  void stageFor(String id, String day) => _updateTask(id, (t) => t.copyWith(stagedFor: day));
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

  /// Pays out any newly completed weekly challenges (bonus XP on 'General'). Returns them for feedback.
  List<Challenge> claimChallenges() {
    final today = _today;
    final done = claimable(state, today);
    if (done.isEmpty) return const [];
    final xp = done.fold<int>(0, (a, c) => a + c.rewardXp);
    _set(state.copyWith(
      claimedChallenges: [...state.claimedChallenges, for (final c in done) claimKey(today, c.id)],
      skillXp: {...state.skillXp, 'Challenges': (state.skillXp['Challenges'] ?? 0) + xp},
    ));
    return done;
  }

  void _awardBadgesQuiet() {
    final nb = newBadges(state, _today);
    if (nb.isNotEmpty) _set(state.copyWith(badges: [...state.badges, ...nb]));
  }

  // ---- platform sync ----
  Future<SyncReport> sync({bool force = false}) async {
    final client = ref.read(httpClientProvider);
    final clock = ref.read(clockProvider);
    final jobs = <(PlatformProvider, String, String)>[
      if (state.githubUser.isNotEmpty) (GithubProvider(client, now: clock), state.githubUser, 'GitHub'),
      if (state.leetcodeUser.isNotEmpty) (LeetcodeProvider(client, now: clock), state.leetcodeUser, 'LeetCode'),
      if (state.codeforcesUser.isNotEmpty) (CodeforcesProvider(client, now: clock), state.codeforcesUser, 'Codeforces'),
    ];
    final results = await Future.wait(jobs.map((j) async {
      final (p, user, label) = j;
      final cached = state.snapshots[p.id];
      if (!force && cached != null && cached.username == user &&
          clock().difference(cached.fetchedAt).inMinutes < 30) {
        return PlatformResult(p.id, label, ok: true, skipped: true, message: _summary(cached));
      }
      try {
        final snap = await p.fetch(user);
        _set(state.copyWith(
          snapshots: {...state.snapshots, p.id: snap},
          syncErrors: {...state.syncErrors}..remove(p.id),
        ));
        return PlatformResult(p.id, label, ok: true, message: _summary(snap));
      } on PlatformException catch (e) {
        _set(state.copyWith(syncErrors: {...state.syncErrors, p.id: e.message}));
        return PlatformResult(p.id, label, ok: false, message: e.message);
      } catch (_) {
        final msg = 'Could not reach $label';
        _set(state.copyWith(syncErrors: {...state.syncErrors, p.id: msg}));
        return PlatformResult(p.id, label, ok: false, message: msg);
      }
    }));
    return SyncReport(results, _autoComplete());
  }

  String _summary(PlatformSnapshot s) => switch (s.platform) {
        'github' => '${s.stats['repos'] ?? 0} repos · ${s.stats['weekCommits'] ?? 0} commits this week',
        'codeforces' =>
          '${s.stats['solved'] ?? 0} solved${(s.stats['rating'] ?? 0) > 0 ? ' · rating ${s.stats['rating']}' : ''}',
        _ => '${s.stats['solved'] ?? 0} solved · ${s.stats['weekSolved'] ?? 0} this week',
      };

  /// Ticks tasks that platform activity has satisfied; returns them for feedback.
  List<Task> _autoComplete() {
    final today = _today;
    final hits = satisfiedTasks(state, today);
    if (hits.isEmpty) return const [];
    final ids = hits.map((t) => t.id).toSet();
    _set(state.copyWith(tasks: [
      for (final t in state.tasks)
        ids.contains(t.id) ? t.copyWith(done: true, auto: true, doneDay: today) : t,
    ]));
    _awardBadgesQuiet();
    return hits;
  }

  /// Undo support for swipe-deletes.
  void restoreTask(Task t) {
    if (state.tasks.any((x) => x.id == t.id)) return;
    _set(state.copyWith(tasks: [...state.tasks, t]));
  }

  void restoreWallet(WalletItem w) {
    if (state.wallet.any((x) => x.id == w.id)) return;
    _set(state.copyWith(wallet: [w, ...state.wallet]));
  }

  /// Validate a username before onboarding finishes.
  Future<PlatformSnapshot> probe(String platform, String user) async {
    final client = ref.read(httpClientProvider);
    final clock = ref.read(clockProvider);
    final PlatformProvider p = switch (platform) {
      'github' => GithubProvider(client, now: clock),
      'codeforces' => CodeforcesProvider(client, now: clock),
      _ => LeetcodeProvider(client, now: clock),
    };
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

  static const focusLogCap = 200;

  void addFocusSession(FocusSession f) {
    final log = [...state.focusLog, f];
    _set(state.copyWith(focusLog: log.length > focusLogCap ? log.sublist(log.length - focusLogCap) : log));
  }

  void updateFocusSession(String id, {String? message, String? outcome}) => _set(state.copyWith(
        focusLog: [for (final f in state.focusLog) f.id == id ? f.copyWith(message: message, outcome: outcome) : f],
      ));

  // ---- friends (public usernames only, no backend) ----
  Friend addFriend({required String name, String github = '', String leetcode = '', String codeforces = ''}) {
    final f = Friend(id: _uuid.v4(), name: name, github: github, leetcode: leetcode, codeforces: codeforces);
    _set(state.copyWith(friends: [...state.friends, f]));
    return f;
  }

  void removeFriend(String id) => _set(state.copyWith(friends: state.friends.where((f) => f.id != id).toList()));
  void restoreFriend(Friend f) {
    if (state.friends.any((x) => x.id == f.id)) return;
    _set(state.copyWith(friends: [...state.friends, f]));
  }

  /// Refreshes every friend's public stats. Each platform fails independently.
  Future<int> refreshFriends({bool force = false}) async {
    final client = ref.read(httpClientProvider);
    final clock = ref.read(clockProvider);
    var failures = 0;
    await Future.wait(state.friends.map((f) async {
      if (!force && f.fetchedAt != null && clock().difference(f.fetchedAt!).inMinutes < 30) return;
      final jobs = <PlatformProvider, String>{
        if (f.github.isNotEmpty) GithubProvider(client, now: clock): f.github,
        if (f.leetcode.isNotEmpty) LeetcodeProvider(client, now: clock): f.leetcode,
        if (f.codeforces.isNotEmpty) CodeforcesProvider(client, now: clock): f.codeforces,
      };
      final snaps = <String, PlatformSnapshot>{...f.snapshots};
      String? err;
      for (final e in jobs.entries) {
        try {
          snaps[e.key.id] = await e.key.fetch(e.value);
        } on PlatformException catch (x) {
          err ??= '${e.key.id}: ${x.message}';
        } catch (_) {
          err ??= 'Could not reach ${e.key.id}';
        }
      }
      if (err != null) failures++;
      _set(state.copyWith(friends: [
        for (final x in state.friends)
          x.id == f.id ? x.copyWith(snapshots: snaps, fetchedAt: clock(), error: err, clearError: err == null) : x,
      ]));
    }));
    return failures;
  }

  /// Replace everything with a restored backup.
  void replaceState(AppState s) => _set(s);

  void resetAll() => _set(AppState());
}
