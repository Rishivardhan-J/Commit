import '../core/utils/day_key.dart';
import '../data/models.dart';
import 'streak_engine.dart';
import 'package:flutter/widgets.dart' show IconData;
import '../core/icons.dart';

class Challenge {
  final String id;
  final String title;
  final IconData icon;
  final int target;
  final int progress;
  final int rewardXp;
  const Challenge(this.id, this.title, this.icon, this.target, this.progress, this.rewardXp);
  bool get done => progress >= target;
  double get fraction => (progress / target).clamp(0.0, 1.0);
}

/// Monday of the week containing [day].
String weekStart(String day) {
  final d = parseDayKey(day);
  return dayKey(DateTime(d.year, d.month, d.day - (d.weekday - 1)));
}

/// ISO-ish week label used to namespace claimed rewards, e.g. "2026-11-09".
String weekId(String day) => weekStart(day);

int _inWeek(Iterable<String> days, String start, String today) =>
    days.where((d) => d.compareTo(start) >= 0 && d.compareTo(today) <= 0).length;

/// Three challenges per week, generated from the user's own data so they are
/// reachable but stretch a little. Progress is derived (never stored), so it can't drift.
List<Challenge> weeklyChallenges(AppState s, String today) {
  final start = weekStart(today);
  final committedDays = _inWeek({for (final c in s.commits.where((c) => !c.frozen)) c.day}, start, today);
  final tasksDone = s.tasks.where((t) => t.done && t.doneDay != null && t.doneDay!.compareTo(start) >= 0 && t.doneDay!.compareTo(today) <= 0).length;
  final focus = s.focusByDay.entries.where((e) => e.key.compareTo(start) >= 0 && e.key.compareTo(today) <= 0).fold<int>(0, (a, e) => a + e.value);

  // Targets scale a little with how active the user already is (last 4 weeks of commits).
  final recentCommits = s.commits.where((c) => !c.frozen && daysBetween(c.day, today) < 28).length;
  final dayTarget = recentCommits >= 20 ? 6 : recentCommits >= 8 ? 5 : 4;
  final taskTarget = recentCommits >= 20 ? 12 : recentCommits >= 8 ? 8 : 5;
  final focusTarget = recentCommits >= 20 ? 180 : recentCommits >= 8 ? 120 : 75;

  return [
    Challenge('days', 'Commit $dayTarget days this week', AppIcons.flame, dayTarget, committedDays, 60),
    Challenge('tasks', 'Finish $taskTarget tasks', AppIcons.listChecks, taskTarget, tasksDone, 50),
    Challenge('focus', 'Focus for $focusTarget minutes', AppIcons.timer, focusTarget, focus, 50),
  ];
}

String claimKey(String today, String id) => '${weekId(today)}:$id';

/// Completed but not yet rewarded.
List<Challenge> claimable(AppState s, String today) => [
      for (final c in weeklyChallenges(s, today))
        if (c.done && !s.claimedChallenges.contains(claimKey(today, c.id))) c,
    ];

bool streakAtLeast(AppState s, String today, int n) => computeStreak(s, today).current >= n;
