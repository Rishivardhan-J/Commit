import '../core/utils/day_key.dart';
import '../data/models.dart';

class StreakInfo {
  final int current;
  final int best;
  final bool committedToday;
  final bool atRisk; // not yet committed today and a streak is running
  const StreakInfo(this.current, this.best, this.committedToday, this.atRisk);
}

/// A day "counts" if it holds a real commit, a stash-frozen day, or a planned rest day.
Set<String> countedDays(AppState s) => {
      for (final c in s.commits) c.day,
      ...s.restDays,
    };

StreakInfo computeStreak(AppState s, String today) {
  final days = countedDays(s);
  final committedToday = s.commits.any((c) => c.day == today && !c.frozen);
  var cursor = committedToday || days.contains(today) ? today : addDays(today, -1);
  var current = 0;
  while (days.contains(cursor)) {
    current++;
    cursor = addDays(cursor, -1);
  }
  // best streak
  final sorted = days.toList()..sort();
  var best = 0, run = 0;
  String? prev;
  for (final d in sorted) {
    run = (prev != null && daysBetween(prev, d) == 1) ? run + 1 : 1;
    if (run > best) best = run;
    prev = d;
  }
  return StreakInfo(current, best, committedToday, !committedToday && current > 0);
}

/// Applies a stash to yesterday if it was missed and a stash exists.
/// Returns the updated state (unchanged if nothing to do).
AppState applyStashIfNeeded(AppState s, String today) {
  final yesterday = addDays(today, -1);
  if (s.stash <= 0) return s;
  final days = countedDays(s);
  if (days.contains(yesterday)) return s;
  // Only protect an existing streak: the day before yesterday must count.
  if (!days.contains(addDays(today, -2))) return s;
  return s.copyWith(
    stash: s.stash - 1,
    commits: [...s.commits, DayCommit(day: yesterday, frozen: true, message: 'stashed — streak protected')],
  );
}

/// One stash per 7-day streak milestone, max 2 held.
AppState awardStash(AppState s, int streak) {
  final milestone = (streak ~/ 7) * 7;
  if (milestone <= 0 || milestone <= s.stashEarnedAt) return s;
  return s.copyWith(
    stash: s.stash >= 2 ? 2 : s.stash + 1,
    stashEarnedAt: milestone,
  );
}

/// "Hotfix": missed exactly yesterday with no stash, but the day before counted.
/// Committing a double day (2+ tasks) today repairs the chain.
bool hotfixAvailable(AppState s, String today) {
  final days = countedDays(s);
  return s.stash == 0 &&
      !days.contains(today) &&
      !days.contains(addDays(today, -1)) &&
      days.contains(addDays(today, -2));
}

AppState applyHotfix(AppState s, String today) => s.copyWith(
      commits: [
        ...s.commits,
        DayCommit(day: addDays(today, -1), frozen: true, message: 'hotfix — double day repaired the streak'),
      ],
    );
