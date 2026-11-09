import 'dart:convert';

enum TaskType { dsa, project, learning, hackathon, openSource }

extension TaskTypeX on TaskType {
  String get label => switch (this) {
        TaskType.dsa => 'DSA practice',
        TaskType.project => 'Project work',
        TaskType.learning => 'Learning',
        TaskType.hackathon => 'Hackathon prep',
        TaskType.openSource => 'Open source',
      };
}

enum WalletKind { idea, hackathon, project, resource, snippet }

extension WalletKindX on WalletKind {
  String get label => switch (this) {
        WalletKind.idea => 'Ideas',
        WalletKind.hackathon => 'Hackathons',
        WalletKind.project => 'Projects',
        WalletKind.resource => 'Resources',
        WalletKind.snippet => 'Snippets',
      };
}

/// Auto-complete rule, e.g. metric `lc.solved` target 2 => "solve 2 LeetCode problems today".
class AutoRule {
  final String metric; // lc.solved | gh.commits
  final int target;
  const AutoRule(this.metric, this.target);
  Map<String, dynamic> toJson() => {'m': metric, 't': target};
  factory AutoRule.fromJson(Map<String, dynamic> j) =>
      AutoRule(j['m'] as String, j['t'] as int);
  String get label => switch (metric) {
        'lc.solved' => 'LeetCode: solve $target today',
        'gh.commits' => 'GitHub: $target commit${target == 1 ? '' : 's'} today',
        'cf.solved' => 'Codeforces: solve $target today',
        _ => metric,
      };
}

class Task {
  final String id;
  final String title;
  final TaskType type;
  final String skill;
  final int difficulty; // 1..3
  final String fallback; // 2-minute minimum viable version
  final String? stagedFor; // dayKey when staged
  final bool done;
  final bool doneViaFallback;
  final bool auto; // completed by CI (platform activity)
  final String? doneDay;
  final AutoRule? rule;

  const Task({
    required this.id,
    required this.title,
    required this.type,
    required this.skill,
    this.difficulty = 1,
    this.fallback = '',
    this.stagedFor,
    this.done = false,
    this.doneViaFallback = false,
    this.auto = false,
    this.doneDay,
    this.rule,
  });

  int get xp => (10 * difficulty * (doneViaFallback ? 0.5 : 1)).round();

  Task copyWith({
    String? title,
    String? stagedFor,
    bool clearStaged = false,
    bool? done,
    bool? doneViaFallback,
    bool? auto,
    String? doneDay,
    bool clearDone = false,
  }) =>
      Task(
        id: id,
        title: title ?? this.title,
        type: type,
        skill: skill,
        difficulty: difficulty,
        fallback: fallback,
        stagedFor: clearStaged ? null : (stagedFor ?? this.stagedFor),
        done: done ?? this.done,
        doneViaFallback: doneViaFallback ?? this.doneViaFallback,
        auto: auto ?? this.auto,
        doneDay: clearDone ? null : (doneDay ?? this.doneDay),
        rule: rule,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type.name,
        'skill': skill,
        'diff': difficulty,
        'fb': fallback,
        'staged': stagedFor,
        'done': done,
        'dfb': doneViaFallback,
        'auto': auto,
        'doneDay': doneDay,
        'rule': rule?.toJson(),
      };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'],
        title: j['title'],
        type: TaskType.values.byName(j['type']),
        skill: j['skill'],
        difficulty: j['diff'] ?? 1,
        fallback: j['fb'] ?? '',
        stagedFor: j['staged'],
        done: j['done'] ?? false,
        doneViaFallback: j['dfb'] ?? false,
        auto: j['auto'] ?? false,
        doneDay: j['doneDay'],
        rule: j['rule'] == null ? null : AutoRule.fromJson(j['rule']),
      );
}

class DayCommit {
  final String day;
  final String message;
  final int xp; // total earned that day (task xp + bonus)
  final int bonus; // commit ceremony + critical bonus
  final int tasks;
  final bool critical;
  final bool frozen; // covered by a stash, no real commit
  const DayCommit({
    required this.day,
    this.message = '',
    this.xp = 0,
    this.bonus = 0,
    this.tasks = 0,
    this.critical = false,
    this.frozen = false,
  });

  Map<String, dynamic> toJson() => {
        'day': day,
        'msg': message,
        'xp': xp,
        'bonus': bonus,
        'n': tasks,
        'crit': critical,
        'frozen': frozen,
      };
  factory DayCommit.fromJson(Map<String, dynamic> j) => DayCommit(
        day: j['day'],
        message: j['msg'] ?? '',
        xp: j['xp'] ?? 0,
        bonus: j['bonus'] ?? 0,
        tasks: j['n'] ?? 0,
        critical: j['crit'] ?? false,
        frozen: j['frozen'] ?? false,
      );
}

class WalletItem {
  final String id;
  final WalletKind kind;
  final String title;
  final String body;
  final List<String> tags;
  final String status; // idea: raw/in progress/shelved
  final bool pinned;
  final Map<String, String> extra; // stack, link, start, end, team, theme, result
  const WalletItem({
    required this.id,
    required this.kind,
    required this.title,
    this.body = '',
    this.tags = const [],
    this.status = 'raw',
    this.pinned = false,
    this.extra = const {},
  });

  WalletItem copyWith({bool? pinned, String? status}) => WalletItem(
        id: id,
        kind: kind,
        title: title,
        body: body,
        tags: tags,
        status: status ?? this.status,
        pinned: pinned ?? this.pinned,
        extra: extra,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'body': body,
        'tags': tags,
        'status': status,
        'pinned': pinned,
        'extra': extra,
      };
  factory WalletItem.fromJson(Map<String, dynamic> j) => WalletItem(
        id: j['id'],
        kind: WalletKind.values.byName(j['kind']),
        title: j['title'],
        body: j['body'] ?? '',
        tags: List<String>.from(j['tags'] ?? const []),
        status: j['status'] ?? 'raw',
        pinned: j['pinned'] ?? false,
        extra: Map<String, String>.from(j['extra'] ?? const {}),
      );
}

/// Cached data pulled from a coding platform.
class PlatformSnapshot {
  final String platform; // github | leetcode
  final String username;
  final DateTime fetchedAt;
  final Map<String, int> activity; // dayKey -> count
  final Map<String, num> stats; // platform specific numbers
  final Map<String, int> breakdown; // languages (github) / topic tags (leetcode)
  const PlatformSnapshot({
    required this.platform,
    required this.username,
    required this.fetchedAt,
    this.activity = const {},
    this.stats = const {},
    this.breakdown = const {},
  });

  Map<String, dynamic> toJson() => {
        'p': platform,
        'u': username,
        'at': fetchedAt.toIso8601String(),
        'act': activity,
        'stats': stats,
        'bd': breakdown,
      };
  factory PlatformSnapshot.fromJson(Map<String, dynamic> j) => PlatformSnapshot(
        platform: j['p'],
        username: j['u'],
        fetchedAt: DateTime.parse(j['at']),
        activity: Map<String, int>.from(j['act'] ?? const {}),
        stats: Map<String, num>.from(j['stats'] ?? const {}),
        breakdown: Map<String, int>.from(j['bd'] ?? const {}),
      );
}

/// One finished focus block: the "commit message" you wrote before starting and how it went.
class FocusSession {
  final String id, day, skill;
  final String message;
  final String outcome; // shipped | partly | notyet
  final int minutes, interruptions, awaySec;
  final String? taskId;
  const FocusSession({
    required this.id,
    required this.day,
    required this.skill,
    required this.minutes,
    this.message = '',
    this.outcome = 'shipped',
    this.interruptions = 0,
    this.awaySec = 0,
    this.taskId,
  });

  /// Short git-style hash shown in the log.
  String get hash => id.replaceAll('-', '').substring(0, 7);

  FocusSession copyWith({String? message, String? outcome}) => FocusSession(
        id: id,
        day: day,
        skill: skill,
        minutes: minutes,
        message: message ?? this.message,
        outcome: outcome ?? this.outcome,
        interruptions: interruptions,
        awaySec: awaySec,
        taskId: taskId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'day': day,
        'skill': skill,
        'min': minutes,
        'msg': message,
        'out': outcome,
        'int': interruptions,
        'away': awaySec,
        'task': taskId,
      };

  factory FocusSession.fromJson(Map<String, dynamic> j) => FocusSession(
        id: j['id'],
        day: j['day'],
        skill: j['skill'] ?? 'General',
        minutes: j['min'] ?? 0,
        message: j['msg'] ?? '',
        outcome: j['out'] ?? 'shipped',
        interruptions: j['int'] ?? 0,
        awaySec: j['away'] ?? 0,
        taskId: j['task'],
      );
}

/// A friend tracked by public usernames only; stats come from the same public APIs.
class Friend {
  final String id;
  final String name;
  final String github;
  final String leetcode;
  final String codeforces;
  final Map<String, PlatformSnapshot> snapshots;
  final DateTime? fetchedAt;
  final String? error;
  const Friend({
    required this.id,
    required this.name,
    this.github = '',
    this.leetcode = '',
    this.codeforces = '',
    this.snapshots = const {},
    this.fetchedAt,
    this.error,
  });

  Friend copyWith({Map<String, PlatformSnapshot>? snapshots, DateTime? fetchedAt, String? error, bool clearError = false}) => Friend(
        id: id,
        name: name,
        github: github,
        leetcode: leetcode,
        codeforces: codeforces,
        snapshots: snapshots ?? this.snapshots,
        fetchedAt: fetchedAt ?? this.fetchedAt,
        error: clearError ? null : (error ?? this.error),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'gh': github,
        'lc': leetcode,
        'cf': codeforces,
        'snaps': snapshots.map((k, v) => MapEntry(k, v.toJson())),
        'at': fetchedAt?.toIso8601String(),
        'err': error,
      };
  factory Friend.fromJson(Map<String, dynamic> j) => Friend(
        id: j['id'],
        name: j['name'],
        github: j['gh'] ?? '',
        leetcode: j['lc'] ?? '',
        codeforces: j['cf'] ?? '',
        snapshots: {
          for (final e in (j['snaps'] as Map? ?? const {}).entries)
            e.key as String: PlatformSnapshot.fromJson(Map<String, dynamic>.from(e.value)),
        },
        fetchedAt: j['at'] == null ? null : DateTime.parse(j['at']),
        error: j['err'],
      );
}

class AppState {
  final bool onboarded;
  final String name;
  final String identity;
  final List<String> focusSkills;
  final String githubUser;
  final String leetcodeUser;
  final String codeforcesUser;
  final String themeMode; // system | light | dark
  final bool notifications;
  final int reminderHour; // evening commit reminder
  final List<Task> tasks;
  final List<DayCommit> commits;
  final Map<String, int> skillXp;
  final int stash;
  final int stashEarnedAt; // streak length at which last stash was earned
  final List<String> badges;
  final List<String> restDays;
  final List<String> dismissedSuggestions; // "day|title"
  final List<WalletItem> wallet;
  final Map<String, PlatformSnapshot> snapshots;
  final Map<String, String> syncErrors;
  final Map<String, int> focusMinutes; // skill -> total focused minutes
  final Map<String, int> focusByDay; // dayKey -> minutes
  final List<Friend> friends;
  final List<String> claimedChallenges; // "2026-W46:id"
  final List<FocusSession> focusLog; // newest last, capped

  const AppState({
    this.onboarded = false,
    this.name = '',
    this.identity = '',
    this.focusSkills = const [],
    this.githubUser = '',
    this.leetcodeUser = '',
    this.codeforcesUser = '',
    this.themeMode = 'system',
    this.notifications = true,
    this.reminderHour = 21,
    this.tasks = const [],
    this.commits = const [],
    this.skillXp = const {},
    this.stash = 0,
    this.stashEarnedAt = 0,
    this.badges = const [],
    this.restDays = const [],
    this.dismissedSuggestions = const [],
    this.wallet = const [],
    this.snapshots = const {},
    this.syncErrors = const {},
    this.focusMinutes = const {},
    this.focusByDay = const {},
    this.friends = const [],
    this.claimedChallenges = const [],
    this.focusLog = const [],
  });

  int get totalXp =>
      skillXp.values.fold(0, (a, b) => a + b) + commits.fold(0, (a, c) => a + c.bonus);

  AppState copyWith({
    bool? onboarded,
    String? name,
    String? identity,
    List<String>? focusSkills,
    String? githubUser,
    String? leetcodeUser,
    String? codeforcesUser,
    String? themeMode,
    bool? notifications,
    int? reminderHour,
    List<Task>? tasks,
    List<DayCommit>? commits,
    Map<String, int>? skillXp,
    int? stash,
    int? stashEarnedAt,
    List<String>? badges,
    List<String>? restDays,
    List<String>? dismissedSuggestions,
    List<WalletItem>? wallet,
    Map<String, PlatformSnapshot>? snapshots,
    Map<String, String>? syncErrors,
    Map<String, int>? focusMinutes,
    Map<String, int>? focusByDay,
    List<Friend>? friends,
    List<String>? claimedChallenges,
    List<FocusSession>? focusLog,
  }) =>
      AppState(
        onboarded: onboarded ?? this.onboarded,
        name: name ?? this.name,
        identity: identity ?? this.identity,
        focusSkills: focusSkills ?? this.focusSkills,
        githubUser: githubUser ?? this.githubUser,
        leetcodeUser: leetcodeUser ?? this.leetcodeUser,
        codeforcesUser: codeforcesUser ?? this.codeforcesUser,
        themeMode: themeMode ?? this.themeMode,
        notifications: notifications ?? this.notifications,
        reminderHour: reminderHour ?? this.reminderHour,
        tasks: tasks ?? this.tasks,
        commits: commits ?? this.commits,
        skillXp: skillXp ?? this.skillXp,
        stash: stash ?? this.stash,
        stashEarnedAt: stashEarnedAt ?? this.stashEarnedAt,
        badges: badges ?? this.badges,
        restDays: restDays ?? this.restDays,
        dismissedSuggestions: dismissedSuggestions ?? this.dismissedSuggestions,
        wallet: wallet ?? this.wallet,
        snapshots: snapshots ?? this.snapshots,
        syncErrors: syncErrors ?? this.syncErrors,
        focusMinutes: focusMinutes ?? this.focusMinutes,
        focusByDay: focusByDay ?? this.focusByDay,
        friends: friends ?? this.friends,
        claimedChallenges: claimedChallenges ?? this.claimedChallenges,
        focusLog: focusLog ?? this.focusLog,
      );

  Map<String, dynamic> toJson() => {
        'onboarded': onboarded,
        'name': name,
        'identity': identity,
        'focus': focusSkills,
        'gh': githubUser,
        'lc': leetcodeUser,
        'cf': codeforcesUser,
        'theme': themeMode,
        'notif': notifications,
        'remind': reminderHour,
        'tasks': tasks.map((e) => e.toJson()).toList(),
        'commits': commits.map((e) => e.toJson()).toList(),
        'skillXp': skillXp,
        'stash': stash,
        'stashAt': stashEarnedAt,
        'badges': badges,
        'rest': restDays,
        'dismissed': dismissedSuggestions,
        'wallet': wallet.map((e) => e.toJson()).toList(),
        'snaps': snapshots.map((k, v) => MapEntry(k, v.toJson())),
        'focusMin': focusMinutes,
        'focusDay': focusByDay,
        'friends': friends.map((e) => e.toJson()).toList(),
        'claimed': claimedChallenges,
        'flog': focusLog.map((e) => e.toJson()).toList(),
        'v': 2,
      };

  factory AppState.fromJson(Map<String, dynamic> j) => AppState(
        onboarded: j['onboarded'] ?? false,
        name: j['name'] ?? '',
        identity: j['identity'] ?? '',
        focusSkills: List<String>.from(j['focus'] ?? const []),
        githubUser: j['gh'] ?? '',
        leetcodeUser: j['lc'] ?? '',
        codeforcesUser: j['cf'] ?? '',
        themeMode: j['theme'] ?? 'system',
        notifications: j['notif'] ?? true,
        reminderHour: j['remind'] ?? 21,
        tasks: [for (final t in j['tasks'] ?? const []) Task.fromJson(t)],
        commits: [for (final c in j['commits'] ?? const []) DayCommit.fromJson(c)],
        skillXp: Map<String, int>.from(j['skillXp'] ?? const {}),
        stash: j['stash'] ?? 0,
        stashEarnedAt: j['stashAt'] ?? 0,
        badges: List<String>.from(j['badges'] ?? const []),
        restDays: List<String>.from(j['rest'] ?? const []),
        dismissedSuggestions: List<String>.from(j['dismissed'] ?? const []),
        wallet: [for (final w in j['wallet'] ?? const []) WalletItem.fromJson(w)],
        snapshots: {
          for (final e in (j['snaps'] as Map? ?? const {}).entries)
            e.key as String: PlatformSnapshot.fromJson(Map<String, dynamic>.from(e.value)),
        },
        focusMinutes: Map<String, int>.from(j['focusMin'] ?? const {}),
        focusByDay: Map<String, int>.from(j['focusDay'] ?? const {}),
        friends: [for (final f in j['friends'] ?? const []) Friend.fromJson(Map<String, dynamic>.from(f))],
        claimedChallenges: List<String>.from(j['claimed'] ?? const []),
        focusLog: [for (final f in j['flog'] ?? const []) FocusSession.fromJson(Map<String, dynamic>.from(f))],
      );

  String encode() => jsonEncode(toJson());
  static AppState decode(String s) => AppState.fromJson(jsonDecode(s));
}
